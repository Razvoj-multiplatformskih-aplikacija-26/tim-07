import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import '../widgets/calendar_columns.dart';
import '../widgets/reservation_details_panel.dart';

/// Dnevni i nedeljni kalendar rezervacija terena vlasnika.
///
/// Stranica šalje događaje `CalendarBloc`-u i crta njegovo stanje; redove
/// kalendara računa domen. Izbor rezervacije otvara iste detalje i akcije kao
/// tabela rezervacija.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  static const wideBreakpoint = 900.0;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _actionsFocus = FocusNode(debugLabel: 'Akcije rezervacije u kalendaru');
  bool _narrowDetailsOpen = false;

  @override
  void initState() {
    super.initState();
    // Rezervacije i blokade su se možda promenile dok je bila druga stranica.
    context.read<CalendarBloc>().add(const CalendarRefreshed());
  }

  @override
  void dispose() {
    _actionsFocus.dispose();
    super.dispose();
  }

  void _open(Reservation reservation, {required bool wide}) {
    context.read<ReservationSelectionBloc>().add(
      ReservationSelected(reservation.id),
    );
    if (wide) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _actionsFocus.context != null) {
          _actionsFocus.requestFocus();
        }
      });
    } else {
      setState(() => _narrowDetailsOpen = true);
    }
  }

  void _closeNarrowDetails() {
    setState(() => _narrowDetailsOpen = false);
  }

  void _send(CalendarEvent event) => context.read<CalendarBloc>().add(event);

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Posle potvrde ili otkazivanja rezervacije kalendar se osvežava.
        BlocListener<ReservationBloc, ReservationState>(
          listenWhen: (previous, current) =>
              previous is ReservationLoading && current is! ReservationLoading,
          listener: (context, state) => _send(const CalendarRefreshed()),
        ),
        BlocListener<ReservationSelectionBloc, ReservationSelectionState>(
          listenWhen: (previous, current) =>
              previous.selectedId != null && current.selectedId == null,
          listener: (context, state) {
            if (_narrowDetailsOpen) _closeNarrowDetails();
          },
        ),
      ],
      child: BlocBuilder<CalendarBloc, CalendarState>(
        builder: (context, state) {
          return switch (state) {
            CalendarLoading() => const _Notice(
              icon: CircularProgressIndicator(),
              title: 'Učitavanje kalendara...',
            ),
            CalendarError(:final message) => _Notice(
              icon: Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              title: 'Kalendar nije učitan',
              message: message,
              action: FilledButton.icon(
                autofocus: true,
                onPressed: () => _send(const CalendarRefreshed()),
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ),
            CalendarNoFields() => const _Notice(
              icon: Icon(Icons.stadium_outlined, size: 48),
              title: 'Nemate nijedan teren',
              message: 'Kalendar prikazuje samo vaše terene.',
            ),
            final CalendarLoaded loaded => _Loaded(
              state: loaded,
              actionsFocus: _actionsFocus,
              narrowDetailsOpen: _narrowDetailsOpen,
              onOpen: _open,
              onCloseDetails: _closeNarrowDetails,
            ),
          };
        },
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  final CalendarLoaded state;
  final FocusNode actionsFocus;
  final bool narrowDetailsOpen;
  final void Function(Reservation reservation, {required bool wide}) onOpen;
  final VoidCallback onCloseDetails;

  const _Loaded({
    required this.state,
    required this.actionsFocus,
    required this.narrowDetailsOpen,
    required this.onOpen,
    required this.onCloseDetails,
  });

  bool _hasSelection(BuildContext context) {
    final id = context.read<ReservationSelectionBloc>().state.selectedId;
    return state.reservations.any((reservation) => reservation.id == id);
  }

  Widget _body(BuildContext context, {required bool wide}) {
    final theme = Theme.of(context);

    if (state.refreshing && state.days.isEmpty) {
      return const _Notice(
        icon: CircularProgressIndicator(),
        title: 'Učitavanje kalendara...',
      );
    }

    if (state.days.isEmpty) {
      return _Notice(
        icon: Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: theme.colorScheme.error,
        ),
        title: 'Termini nisu učitani',
        message: state.message,
        action: FilledButton.icon(
          autofocus: true,
          onPressed: () =>
              context.read<CalendarBloc>().add(const CalendarRefreshed()),
          icon: const Icon(Icons.refresh),
          label: const Text('Pokušaj ponovo'),
        ),
      );
    }

    return CalendarColumns(
      state: state,
      onOpen: (reservation) => onOpen(reservation, wide: wide),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            context.read<CalendarBloc>().add(const CalendarMoved(-1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            context.read<CalendarBloc>().add(const CalendarMoved(1)),
        const SingleActivator(LogicalKeyboardKey.keyT): () =>
            context.read<CalendarBloc>().add(const CalendarTodayRequested()),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= CalendarPage.wideBreakpoint;
            final showDetails =
                !wide && narrowDetailsOpen && _hasSelection(context);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showDetails) ...[
                  _Controls(state: state),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: CalendarLegend(),
                  ),
                ],
                SizedBox(
                  height: 4,
                  child: state.refreshing
                      ? const LinearProgressIndicator()
                      : null,
                ),
                if (state.message case final message?
                    when state.days.isNotEmpty)
                  _Banner(message: message),
                Expanded(
                  child: showDetails
                      ? _NarrowDetails(
                          state: state,
                          actionsFocus: actionsFocus,
                          onBack: onCloseDetails,
                        )
                      : wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _body(context, wide: true)),
                            const VerticalDivider(width: 1),
                            SizedBox(
                              width: 360,
                              child: ReservationDetailsPanel(
                                reservations: state.reservations,
                                actionsFocusNode: actionsFocus,
                              ),
                            ),
                          ],
                        )
                      : _body(context, wide: false),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NarrowDetails extends StatelessWidget {
  final CalendarLoaded state;
  final FocusNode actionsFocus;
  final VoidCallback onBack;

  const _NarrowDetails({
    required this.state,
    required this.actionsFocus,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              autofocus: true,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Nazad na kalendar'),
            ),
          ),
        ),
        Expanded(
          child: ReservationDetailsPanel(
            reservations: state.reservations,
            actionsFocusNode: actionsFocus,
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final CalendarLoaded state;

  const _Controls({required this.state});

  String get _rangeLabel {
    if (state.view == CalendarView.day) {
      return '${weekdayLong(state.date)}, ${formatDate(state.date)}';
    }
    final last = state.rangeEnd.subtract(const Duration(days: 1));
    return '${formatDayMonth(state.rangeStart)} - ${formatDate(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CalendarBloc>();
    final theme = Theme.of(context);
    final unit = state.view == CalendarView.day ? 'dan' : 'nedelju';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<CalendarView>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: CalendarView.day, label: Text('Dan')),
              ButtonSegment(value: CalendarView.week, label: Text('Nedelja')),
            ],
            selected: {state.view},
            onSelectionChanged: (selection) =>
                bloc.add(CalendarViewChanged(selection.first)),
          ),
          IconButton(
            tooltip: state.view == CalendarView.day
                ? 'Prethodni dan'
                : 'Prethodna nedelja',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => bloc.add(const CalendarMoved(-1)),
          ),
          OutlinedButton(
            onPressed: () => bloc.add(const CalendarTodayRequested()),
            child: const Text('Danas'),
          ),
          IconButton(
            tooltip: state.view == CalendarView.day
                ? 'Sledeći dan'
                : 'Sledeća nedelja',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => bloc.add(const CalendarMoved(1)),
          ),
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                helpText: 'Izaberite $unit',
              );
              if (picked != null) bloc.add(CalendarDateSelected(picked));
            },
            icon: const Icon(Icons.calendar_month),
            label: Semantics(
              header: true,
              liveRegion: true,
              child: Text(_rangeLabel, style: theme.textTheme.titleMedium),
            ),
          ),
          if (state.view == CalendarView.week)
            DropdownButton<FieldId>(
              value: state.field.id,
              items: [
                for (final field in state.fields)
                  DropdownMenuItem(value: field.id, child: Text(field.name)),
              ],
              onChanged: (id) {
                if (id != null) bloc.add(CalendarFieldSelected(id));
              },
            ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;

  const _Banner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? message;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;
    final action = this.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
