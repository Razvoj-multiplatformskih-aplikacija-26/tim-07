import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../actions/reservation_actions.dart';
import '../selection/reservation_selection_bloc.dart';
import '../widgets/reservation_details_panel.dart';
import '../widgets/reservations_table.dart';
import '../widgets/shortcut_hints.dart';

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final _tableFocus = FocusNode(debugLabel: 'Tabela rezervacija');
  final _actionsFocus = FocusNode(debugLabel: 'Akcije rezervacije');
  bool _tableFocused = false;

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

  void _openDetails(List<Reservation> reservations) {
    if (_selected(reservations) == null) {
      _move(reservations, 1);
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

  Map<ShortcutActivator, VoidCallback> _tableShortcuts(
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

  Widget _buildLoaded(List<Reservation> reservations) {
    final colors = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: _pageShortcuts(reservations),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CallbackShortcuts(
                    bindings: _tableShortcuts(reservations),
                    child: Focus(
                      focusNode: _tableFocus,
                      autofocus: true,
                      onFocusChange: (focused) =>
                          setState(() => _tableFocused = focused),
                      child: Listener(
                        onPointerDown: (_) => _tableFocus.requestFocus(),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 2,
                              color: _tableFocused
                                  ? colors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: ReservationsTable(reservations: reservations),
                        ),
                      ),
                    ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReservationBloc, ReservationState>(
      builder: (context, state) {
        return switch (state) {
          ReservationLoaded(:final reservations) => _buildLoaded(reservations),
          ReservationInitial() || ReservationLoading() =>
            const _Message('Učitavanje rezervacija...'),
          ReservationEmpty() => const _Message('Nema rezervacija.'),
          ReservationError(:final message) => _Message('Greška: $message'),
        };
      },
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
