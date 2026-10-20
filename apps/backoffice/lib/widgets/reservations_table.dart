import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/backoffice_demo_data.dart';
import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';

class ReservationsTable extends StatelessWidget {
  final List<Reservation> reservations;

  const ReservationsTable({super.key, required this.reservations});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedId =
        context.watch<ReservationSelectionBloc>().state.selectedId;

    final sorted = [...reservations]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                headingTextStyle: Theme.of(context).textTheme.labelLarge,
                columns: const [
                  DataColumn(label: Text('ID'), numeric: true),
                  DataColumn(label: Text('Teren')),
                  DataColumn(label: Text('Korisnik')),
                  DataColumn(label: Text('Datum')),
                  DataColumn(label: Text('Vreme')),
                  DataColumn(label: Text('Status')),
                ],
                rows: [
                  for (final reservation in sorted)
                    DataRow(
                      key: ValueKey(reservation.id.value),
                      selected: reservation.id == selectedId,
                      color: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? colors.primaryContainer
                            : null,
                      ),
                      onSelectChanged: (_) => context
                          .read<ReservationSelectionBloc>()
                          .add(ReservationSelected(reservation.id)),
                      cells: [
                        DataCell(Text('#${reservation.id.value}')),
                        DataCell(
                          Text(
                            BackofficeDemoData.fieldName(reservation.fieldId),
                          ),
                        ),
                        DataCell(
                          Text(
                            BackofficeDemoData.userName(reservation.userId),
                          ),
                        ),
                        DataCell(Text(formatDate(reservation.startTime))),
                        DataCell(
                          Text(
                            formatTimeRange(
                              reservation.startTime,
                              reservation.endTime,
                            ),
                          ),
                        ),
                        DataCell(
                          ReservationStatusChip(status: reservation.status),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
