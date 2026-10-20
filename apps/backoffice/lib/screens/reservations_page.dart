import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/reservation_details_panel.dart';
import '../widgets/reservations_table.dart';

class ReservationsPage extends StatelessWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReservationBloc, ReservationState>(
      builder: (context, state) {
        return switch (state) {
          ReservationLoaded(:final reservations) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ReservationsTable(reservations: reservations)),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 360,
                  child: ReservationDetailsPanel(reservations: reservations),
                ),
              ],
            ),
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
