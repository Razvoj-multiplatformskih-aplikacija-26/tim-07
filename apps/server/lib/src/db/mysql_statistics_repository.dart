import 'package:domain/domain.dart';

import 'database.dart';
import 'rows.dart';

final class MySqlStatisticsRepository implements StatisticsRepository {
  final SqlExecutor _db;
  final DateTime Function() _clock;

  MySqlStatisticsRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  @override
  Future<OccupancyReport> getOccupancy({required StatsPeriod period, UserId? ownerId}) async {
    final fieldRows = await _db.query(
      'SELECT ${Rows.fieldColumns} FROM sports_fields f WHERE (? IS NULL OR f.owner_id = ?) ORDER BY f.id',
      [ownerId?.value, ownerId?.value],
    );
    final fields = [for (final row in fieldRows) Rows.field(row)];
    if (fields.isEmpty) {
      return OccupancyReport(period: period, fields: const []);
    }

    final ids = [for (final field in fields) field.id.value];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final from = Rows.utc(period.from);
    final to = Rows.utc(period.to);

    final scheduleRows = await _db.query(
      'SELECT field_id, day_of_week, opens_at, closes_at, is_open FROM field_schedules '
      'WHERE field_id IN ($placeholders)',
      ids,
    );
    final blockedRows = await _db.query(
      'SELECT field_id, start_time, end_time, reason FROM blocked_periods '
      'WHERE field_id IN ($placeholders) AND start_time < ? AND end_time > ?',
      [...ids, to, from],
    );
    final reservationRows = await _db.query(
      'SELECT ${Rows.reservationColumns} FROM reservations r '
      'WHERE r.field_id IN ($placeholders) AND r.start_time < ? AND r.end_time > ?',
      [...ids, to, from],
    );

    final now = _clock().toUtc();
    final reservations = [
      for (final row in reservationRows)
        () {
          final reservation = Rows.reservation(row);
          return reservation.copyWith(status: resolveReservationStatus(reservation, now));
        }(),
    ];

    return calculateOccupancyReport(
      period: period,
      fields: fields,
      schedules: [for (final row in scheduleRows) Rows.schedule(row)],
      reservations: reservations,
      blockedPeriods: [for (final row in blockedRows) Rows.blockedPeriod(row)],
    );
  }
}
