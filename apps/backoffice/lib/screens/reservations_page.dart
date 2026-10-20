import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../actions/reservation_actions.dart';
import '../selection/reservation_selection_bloc.dart';
import '../widgets/reservation_details_panel.dart';
import '../widgets/reservations_list.dart';
import '../widgets/reservations_table.dart';
import '../widgets/shortcut_hints.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  static const wideBreakpoint = 900.0;

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _tableFocus = FocusNode(debugLabel: 'Tabela rezervacija');
  final _actionsFocus = FocusNode(debugLabel: 'Akcije rezervacije');
  bool _tableFocused = false;
  bool _isWide = true;
  bool _narrowDetailsOpen = false;
  List<Reservation>? _lastReservations;

  @override
  void dispose() {
    _tableFocus.dispose();
    _actionsFocus.dispose();
    super.dispose();
  }

  Reservation? _selected(List<Reservation> reservations) {
    final id = context.read<ReservationSelectionBloc>().state.selectedId;
    for (final reservation in reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }
    return null;
  }

  void _move(List<Reservation> reservations, int offset) {
    context.read<ReservationSelectionBloc>().add(
          ReservationSelectionMoved(
            offset: offset,
            order: [
              for (final r in ReservationsTable.ordered(reservations)) r.id,
            ],
          ),
        );
  }

  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) {
        node.requestFocus();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _openNarrowDetails() {
    setState(() => _narrowDetailsOpen = true);
    _focusAfterFrame(_actionsFocus);
  }

  void _closeNarrowDetails() {
    setState(() => _narrowDetailsOpen = false);
    _focusAfterFrame(_tableFocus);
  }

  void _openDetails(List<Reservation> reservations) {
    if (_selected(reservations) == null) {
      _move(reservations, 1);
      return;
    }
    if (!_isWide) {
      _openNarrowDetails();
      return;
    }
    if (_actionsFocus.context != null) {
      _actionsFocus.requestFocus();
    }
  }

  void _runAction(List<Reservation> reservations, ReservationStatus target) {
    final reservation = _selected(reservations);
    if (reservation != null) {
      runReservationAction(context, reservation, target);
    }
  }

  void _escape() {
    if (!_isWide && _narrowDetailsOpen) {
      _closeNarrowDetails();
      return;
    }
    if (!_tableFocus.hasFocus) {
      _tableFocus.requestFocus();
      return;
    }
    context.read<ReservationSelectionBloc>().add(
          const ReservationSelectionCleared(),
        );
  }

  void _reload() {
    context.read<ReservationBloc>().add(const ReservationsRequested());
  }

  Map<ShortcutActivator, VoidCallback> _recordShortcuts(
    List<Reservation> reservations,
  ) {
    final length = reservations.length;

    return {
      const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
          _move(reservations, 1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
          _move(reservations, -1),
      const SingleActivator(LogicalKeyboardKey.home): () =>
          _move(reservations, -length),
      const SingleActivator(LogicalKeyboardKey.end): () =>
          _move(reservations, length),
      const SingleActivator(LogicalKeyboardKey.enter): () =>
          _openDetails(reservations),
    };
  }

  Map<ShortcutActivator, VoidCallback> _pageShortcuts(
    List<Reservation> reservations,
  ) {
    return {
      const SingleActivator(LogicalKeyboardKey.keyP): () =>
          _runAction(reservations, ReservationStatus.confirmed),
      const SingleActivator(LogicalKeyboardKey.keyO): () =>
          _runAction(reservations, ReservationStatus.cancelled),
      const SingleActivator(LogicalKeyboardKey.keyR): _reload,
      const SingleActivator(LogicalKeyboardKey.escape): _escape,
    };
  }

  Widget _focusableRecords(List<Reservation> reservations, Widget child) {
    final colors = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: _recordShortcuts(reservations),
      child: Focus(
        focusNode: _tableFocus,
        autofocus: true,
        onFocusChange: (focused) => setState(() => _tableFocused = focused),
        child: Listener(
          onPointerDown: (_) => _tableFocus.requestFocus(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                width: 2,
                color: _tableFocused ? colors.primary : Colors.transparent,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildWide(List<Reservation> reservations) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _focusableRecords(
                  reservations,
                  ReservationsTable(reservations: reservations),
                ),
              ),
              const ShortcutHints(),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 360,
          child: ReservationDetailsPanel(
            reservations: reservations,
            actionsFocusNode: _actionsFocus,
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow(List<Reservation> reservations) {
    if (_narrowDetailsOpen && _selected(reservations) != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                autofocus: true,
                onPressed: _closeNarrowDetails,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Nazad na listu'),
              ),
            ),
          ),
          Expanded(
            child: ReservationDetailsPanel(
              reservations: reservations,
              actionsFocusNode: _actionsFocus,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: _focusableRecords(
            reservations,
            ReservationsList(
              reservations: reservations,
              onOpen: (_) => _openNarrowDetails(),
            ),
          ),
        ),
        const ShortcutHints(),
      ],
    );
  }

  Widget _buildLoaded(List<Reservation> reservations) {
    return BlocListener<ReservationSelectionBloc, ReservationSelectionState>(
      listenWhen: (previous, current) =>
          previous.selectedId != null && current.selectedId == null,
      listener: (context, state) {
        if (_narrowDetailsOpen) {
          _closeNarrowDetails();
        }
      },
      child: CallbackShortcuts(
        bindings: _pageShortcuts(reservations),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _isWide = constraints.maxWidth >= ReservationsPage.wideBreakpoint;

            return _isWide
                ? _buildWide(reservations)
                : _buildNarrow(reservations);
          },
        ),
      ),
    );
  }

  Widget _withProgress(List<Reservation> reservations, {required bool loading}) {
    return Column(
      children: [
        SizedBox(
          height: 4,
          child: loading ? const LinearProgressIndicator() : null,
        ),
        Expanded(child: _buildLoaded(reservations)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReservationBloc, ReservationState>(
      builder: (context, state) {
        if (state is ReservationLoaded) {
          _lastReservations = state.reservations;
        }
        if (state is ReservationEmpty || state is ReservationError) {
          _lastReservations = null;
        }

        final previous = _lastReservations;

        return switch (state) {
          ReservationLoaded(:final reservations) =>
            _withProgress(reservations, loading: false),
          ReservationInitial() || ReservationLoading() when previous != null =>
            _withProgress(previous, loading: true),
          ReservationInitial() || ReservationLoading() => const _LoadingView(),
          ReservationEmpty() => _EmptyView(onReload: _reload),
          ReservationError(:final message) =>
            _ErrorView(message: message, onRetry: _reload),
        };
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const _StateView(
      icon: CircularProgressIndicator(),
      title: 'Učitavanje rezervacija...',
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onReload;

  const _EmptyView({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: Icon(
        Icons.inbox_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: 'Nema rezervacija',
      message: 'Trenutno nema rezervacija za vaše terene.',
      action: OutlinedButton.icon(
        autofocus: true,
        onPressed: onReload,
        icon: const Icon(Icons.refresh),
        label: const Text('Osveži'),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  String get _details => message.replaceFirst('Bad state: ', '');

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: Icon(
        Icons.error_outline,
        size: 48,
        color: Theme.of(context).colorScheme.error,
      ),
      title: 'Rezervacije nisu učitane',
      message: _details,
      action: FilledButton.icon(
        autofocus: true,
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Pokušaj ponovo'),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? message;
  final Widget? action;

  const _StateView({
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
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
