import 'package:domain/domain.dart';

import 'database.dart';
import 'rows.dart';

final class MySqlReservationRepository implements ReservationRepository {
  final Database _database;
  final DateTime Function() _clock;

  MySqlReservationRepository(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  DateTime _now() => _clock().toUtc();

  Future<List<Reservation>> _select(
    SqlExecutor db,
    String where, [
    List<Object?> values = const [],
    String suffix = '',
  ]) async {
    final rows = await db.query(
      'SELECT ${Rows.reservationColumns} FROM reservations r $where '
      'ORDER BY r.start_time, r.id $suffix',
      values,
    );
    return [for (final row in rows) Rows.reservation(row)];
  }

  @override
  Future<List<Reservation>> getReservations() async {
    await _refreshStatuses(_database);
    return _select(_database, '');
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    await _refreshStatuses(_database);
    return _select(_database, 'WHERE r.user_id = ?', [userId.value]);
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    await _refreshStatuses(_database);
    return _select(_database, 'WHERE r.field_id = ?', [fieldId.value]);
  }

  Future<List<Reservation>> getReservationsByOwner(UserId ownerId) async {
    await _refreshStatuses(_database);
    return _select(
      _database,
      'JOIN sports_fields f ON f.id = r.field_id WHERE f.owner_id = ?',
      [ownerId.value],
    );
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    await _refreshStatuses(_database);
    final found = await _select(_database, 'WHERE r.id = ?', [id.value]);
    return found.isEmpty ? null : found.single;
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    return _database.transaction((tx) async {
      final now = _now();

      final fieldLock = await tx.query('SELECT id FROM sports_fields WHERE id = ? FOR UPDATE', [fieldId.value]);
      if (fieldLock.isEmpty) throw EntityNotFound('field', fieldId.value);
      final userLock = await tx.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId.value]);
      if (userLock.isEmpty) throw EntityNotFound('user', userId.value);

      final fieldRows = await tx.query(
        'SELECT ${Rows.fieldColumns} FROM sports_fields f WHERE f.id = ?',
        [fieldId.value],
      );
      final field = Rows.field(fieldRows.first);

      if (!isFieldPublic(field)) {
        throw const ReservationRuleViolation(FieldUnavailable());
      }

      await _refreshStatuses(tx);

      final candidates = await _select(
        tx,
        "WHERE (r.field_id = ? OR r.user_id = ?) AND r.status IN ('pending', 'confirmed') "
        'AND r.start_time < ? AND r.end_time > ?',
        [fieldId.value, userId.value, Rows.utc(endTime), Rows.utc(startTime)],
      );
      final schedules = await _schedules(tx, fieldId);
      final blocked = await _blockedPeriods(tx, fieldId, startTime, endTime);

      final error = validateReservationSlot(
        fieldId: fieldId,
        userId: userId,
        startTime: startTime.toLocal(),
        endTime: endTime.toLocal(),
        now: now.toLocal(),
        existingReservations: candidates,
        schedules: schedules,
        blockedPeriods: blocked,
      );
      if (error != null) throw ReservationRuleViolation(error);

      final status = field.confirmationMode == ConfirmationMode.automatic
          ? ReservationStatus.confirmed
          : ReservationStatus.pending;

      final result = await tx.query(
        'INSERT INTO reservations (field_id, user_id, start_time, end_time, total_price, status, created_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          fieldId.value,
          userId.value,
          Rows.utc(startTime),
          Rows.utc(endTime),
          calculateReservationPrice(
            pricePerHour: field.pricePerHour,
            startTime: startTime,
            endTime: endTime,
          ),
          status.name,
          now,
        ],
      );

      return (await _select(tx, 'WHERE r.id = ?', [result.insertId])).single;
    });
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) =>
      changeStatus(reservationId: reservationId, to: status);

  Future<Reservation> changeStatus({
    required ReservationId reservationId,
    required ReservationStatus to,
    ReservationStatus? from,
    String? reason,
  }) {
    final status = to;
    return _database.transaction((tx) async {
      final now = _now();
      final reservation = await _lockAndRefresh(tx, reservationId, now);

      if (from != null && reservation.status != from) {
        throw const ReservationRuleViolation(InvalidReservationStatus());
      }

      if (!canTransitionReservationStatus(reservation.status, status)) {
        throw const ReservationRuleViolation(InvalidReservationStatus());
      }

      if (status == ReservationStatus.completed) {
        throw const ReservationRuleViolation(InvalidReservationStatus());
      }

      if (status == ReservationStatus.cancelled) {
        final error = validateCancellation(reservation: reservation, now: now);
        if (error != null) throw ReservationRuleViolation(error);
      }

      await tx.query(
        'UPDATE reservations SET status = ?, cancellation_reason = COALESCE(?, cancellation_reason) WHERE id = ?',
        [status.name, reason, reservationId.value],
      );
      return reservation.copyWith(status: status, cancellationReason: reason);
    });
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) {
    return _database.transaction((tx) async {
      final now = _now();
      final reservation = await _lockAndRefresh(tx, reservationId, now);

      final error = validateCheckIn(reservation: reservation, now: now);
      if (error != null) throw ReservationRuleViolation(error);

      await tx.query(
        'UPDATE reservations SET checked_in_at = ? WHERE id = ?',
        [now, reservationId.value],
      );
      return reservation.copyWith(checkedInAt: now);
    });
  }

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) =>
      updateReservationStatus(reservationId: reservationId, status: ReservationStatus.cancelled);

  Future<Reservation> _lockAndRefresh(SqlExecutor tx, ReservationId id, DateTime now) async {
    final found = await _select(tx, 'WHERE r.id = ?', [id.value], 'FOR UPDATE');
    if (found.isEmpty) throw EntityNotFound('reservation', id.value);

    final reservation = found.single;
    final resolved = resolveReservationStatus(reservation, now);
    if (resolved == reservation.status) return reservation;

    await tx.query('UPDATE reservations SET status = ? WHERE id = ?', [resolved.name, id.value]);
    return reservation.copyWith(status: resolved);
  }

  Future<void> _refreshStatuses(SqlExecutor db) async {
    final now = _now();
    final due = await _select(
      db,
      "WHERE r.status IN ('pending', 'confirmed') AND r.start_time <= ?",
      [now.add(const Duration(hours: 5))],
    );

    for (final reservation in due) {
      final resolved = resolveReservationStatus(reservation, now);
      if (resolved != reservation.status) {
        await db.query(
          'UPDATE reservations SET status = ? WHERE id = ? AND status = ?',
          [resolved.name, reservation.id.value, reservation.status.name],
        );
      }
    }
  }

  Future<List<FieldSchedule>> _schedules(SqlExecutor db, FieldId fieldId) async {
    final rows = await db.query(
      'SELECT field_id, day_of_week, opens_at, closes_at, is_open FROM field_schedules WHERE field_id = ?',
      [fieldId.value],
    );
    return [for (final row in rows) Rows.schedule(row)];
  }

  Future<List<BlockedPeriod>> _blockedPeriods(
    SqlExecutor db,
    FieldId fieldId,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await db.query(
      'SELECT field_id, start_time, end_time, reason FROM blocked_periods '
      'WHERE field_id = ? AND start_time < ? AND end_time > ?',
      [fieldId.value, Rows.utc(end), Rows.utc(start)],
    );
    return [for (final row in rows) Rows.blockedPeriod(row)];
  }
}
