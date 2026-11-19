import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/directory.dart';
import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';

class ReservationsTable extends StatelessWidget {
  /// Redovi onim redosledom kojim su stigli: sortiranje radi izvor
  /// (`ReservationQuery`), pa strana i redosled uvek idu zajedno.
  final List<Reservation> reservations;

  /// Kolona po kojoj su redovi sortirani i smer; zaglavlje to pokazuje.
  final ReservationSortKey sortKey;
  final bool ascending;

  /// Klik na zaglavlje sortabilne kolone. Izvor odlučuje o smeru.
  final ValueChanged<ReservationSortKey>? onSort;

  const ReservationsTable({
    super.key,
    required this.reservations,
    this.sortKey = ReservationSortKey.startTime,
    this.ascending = true,
    this.onSort,
  });

  static const _sortColumns = <ReservationSortKey, int>{
    ReservationSortKey.id: 0,
    ReservationSortKey.field: 1,
    ReservationSortKey.user: 2,
    ReservationSortKey.startTime: 3,
    ReservationSortKey.status: 5,
  };

  DataColumn _column(String label, {ReservationSortKey? key, bool numeric = false}) {
    final onSort = this.onSort;
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      tooltip: key == null ? null : 'Sortiraj po koloni: $label',
      onSort: key == null || onSort == null ? null : (_, _) => onSort(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DirectoryCubit>().state;
    final colors = Theme.of(context).colorScheme;
    final selectedId =
        context.watch<ReservationSelectionBloc>().state.selectedId;

    final sorted = reservations;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                sortColumnIndex: _sortColumns[sortKey],
                sortAscending: ascending,
                headingTextStyle: Theme.of(context).textTheme.labelLarge,
                columns: [
                  _column('ID', key: ReservationSortKey.id, numeric: true),
                  _column('Teren', key: ReservationSortKey.field),
                  _column('Korisnik', key: ReservationSortKey.user),
                  _column('Datum', key: ReservationSortKey.startTime),
                  _column('Vreme'),
                  _column('Status', key: ReservationSortKey.status),
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
                            directory.fieldName(reservation.fieldId),
                          ),
                        ),
                        DataCell(
                          Text(
                            directory.customerName(reservation),
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
