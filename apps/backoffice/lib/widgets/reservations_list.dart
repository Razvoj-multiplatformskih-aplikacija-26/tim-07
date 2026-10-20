import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/backoffice_demo_data.dart';
import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';
import 'reservations_table.dart';

class ReservationsList extends StatelessWidget {
  final List<Reservation> reservations;
  final ValueChanged<ReservationId> onOpen;

  const ReservationsList({
    super.key,
    required this.reservations,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedId =
        context.watch<ReservationSelectionBloc>().state.selectedId;
    final sorted = ReservationsTable.ordered(reservations);

    return ListView.separated(
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final reservation = sorted[index];

        return ListTile(
          key: ValueKey(reservation.id.value),
          selected: reservation.id == selectedId,
          selectedTileColor: colors.primaryContainer,
          leading: Text('#${reservation.id.value}'),
          title: Text(BackofficeDemoData.fieldName(reservation.fieldId)),
          subtitle: Text(
            '${BackofficeDemoData.userName(reservation.userId)} · '
            '${formatDate(reservation.startTime)} · '
            '${formatTimeRange(reservation.startTime, reservation.endTime)}',
          ),
          trailing: ReservationStatusChip(status: reservation.status),
          onTap: () {
            context
                .read<ReservationSelectionBloc>()
                .add(ReservationSelected(reservation.id));
            onOpen(reservation.id);
          },
        );
      },
    );
  }
}
