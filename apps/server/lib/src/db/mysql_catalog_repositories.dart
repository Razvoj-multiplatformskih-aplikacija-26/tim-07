import 'package:domain/domain.dart';

import 'database.dart';
import 'rows.dart';

final class MySqlSportsFieldRepository implements SportsFieldRepository {
  final SqlExecutor _db;
  final DateTime Function() _clock;

  MySqlSportsFieldRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  Future<List<SportsField>> _select(String where, [List<Object?> values = const []]) async {
    final rows = await _db.query(
      'SELECT ${Rows.fieldColumns} FROM sports_fields f $where ORDER BY f.name, f.id',
      values,
    );
    return [for (final row in rows) Rows.field(row)];
  }

  @override
  Future<List<SportsField>> getFields() => _select('');

  @override
  Future<List<SportsField>> getPublicFields() async {
    final fields = await _select("WHERE f.is_active = TRUE AND f.approval_status = 'approved'");
    return fields.where(isFieldPublic).toList();
  }

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) =>
      _select('WHERE f.owner_id = ?', [ownerId.value]);

  @override
  Future<SportsField?> getFieldById(FieldId id) async {
    final fields = await _select('WHERE f.id = ?', [id.value]);
    return fields.isEmpty ? null : fields.single;
  }

  @override
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  }) async {
    final result = await _db.query(
      'INSERT INTO sports_fields (owner_id, name, description, sport, address, city, '
      'price_per_hour, contact_phone, confirmation_mode) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        ownerId.value, name, description, sport.name, address, city,
        pricePerHour, contactPhone, confirmationMode.name,
      ],
    );
    final id = FieldId(result.insertId!);
    await _replaceImages(id, imageUrls);
    return (await getFieldById(id))!;
  }

  @override
  Future<SportsField> updateField(SportsField field) async {
    final current = await getFieldById(field.id);
    if (current == null) throw EntityNotFound('field', field.id.value);
    final approval = approvalStatusAfterOwnerEdit(current.approvalStatus);

    await _db.query(
      'UPDATE sports_fields SET name = ?, description = ?, sport = ?, address = ?, city = ?, '
      'price_per_hour = ?, contact_phone = ?, confirmation_mode = ?, is_active = ?, '
      'approval_status = ? WHERE id = ?',
      [
        field.name, field.description, field.sport.name, field.address, field.city,
        field.pricePerHour, field.contactPhone, field.confirmationMode.name,
        field.isActive, approval.name, field.id.value,
      ],
    );
    await _replaceImages(field.id, field.imageUrls);
    return (await getFieldById(field.id))!;
  }

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async {
    final rows = await _db.query(
      'SELECT ${Rows.fieldColumns} FROM sports_fields f '
      "WHERE f.approval_status = 'pending' ORDER BY f.created_at, f.id",
    );
    return [for (final row in rows) Rows.field(row)];
  }

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async {
    final current = await getFieldById(fieldId);
    if (current == null) throw EntityNotFound('field', fieldId.value);
    if (decision == ApprovalStatus.pending ||
        !canTransitionApprovalStatus(current.approvalStatus, decision)) {
      throw ApprovalTransitionNotAllowed(current.approvalStatus, decision);
    }

    final result = await _db.query(
      'UPDATE sports_fields SET approval_status = ?, rejection_reason = ?, reviewed_by = ?, '
      'reviewed_at = ? WHERE id = ? AND approval_status = ?',
      [
        decision.name,
        decision == ApprovalStatus.rejected ? reason : null,
        reviewerId.value,
        _clock().toUtc(),
        fieldId.value,
        current.approvalStatus.name,
      ],
    );
    if (result.affectedRows == 0) {
      final latest = await getFieldById(fieldId);
      throw ApprovalTransitionNotAllowed(latest?.approvalStatus ?? current.approvalStatus, decision);
    }
    return (await getFieldById(fieldId))!;
  }

  Future<void> _replaceImages(FieldId id, List<String> urls) async {
    await _db.query('DELETE FROM field_images WHERE field_id = ?', [id.value]);
    for (var i = 0; i < urls.length; i++) {
      await _db.query(
        'INSERT INTO field_images (field_id, position, url) VALUES (?, ?, ?)',
        [id.value, i, urls[i]],
      );
    }
  }
}

final class MySqlFieldScheduleRepository implements FieldScheduleRepository {
  final Database _db;

  MySqlFieldScheduleRepository(this._db);

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) async {
    final rows = await _db.query(
      'SELECT field_id, day_of_week, opens_at, closes_at, is_open '
      'FROM field_schedules WHERE field_id = ?',
      [fieldId.value],
    );
    final schedules = [for (final row in rows) Rows.schedule(row)];
    schedules.sort((a, b) => a.dayOfWeek.index.compareTo(b.dayOfWeek.index));
    return schedules;
  }

  @override
  Future<void> replaceSchedules(FieldId fieldId, List<FieldSchedule> schedules) async {
    final error = validateFieldSchedule(fieldId: fieldId, schedules: schedules);
    if (error != null) throw ScheduleRuleViolation(error);

    await _db.transaction((tx) async {
      final field = await tx.query('SELECT id FROM sports_fields WHERE id = ? FOR UPDATE', [fieldId.value]);
      if (field.isEmpty) throw EntityNotFound('field', fieldId.value);

      await tx.query('DELETE FROM field_schedules WHERE field_id = ?', [fieldId.value]);
      for (final schedule in schedules) {
        await tx.query(
          'INSERT INTO field_schedules (field_id, day_of_week, opens_at, closes_at, is_open) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            fieldId.value,
            schedule.dayOfWeek.name,
            Rows.time(schedule.opensAt),
            Rows.time(schedule.closesAt),
            schedule.isOpen,
          ],
        );
      }
    });
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = await _db.query(
      'SELECT field_id, start_time, end_time, reason FROM blocked_periods '
      'WHERE field_id = ? AND (? IS NULL OR end_time > ?) AND (? IS NULL OR start_time < ?) '
      'ORDER BY start_time',
      [
        fieldId.value,
        from == null ? null : Rows.utc(from), from == null ? null : Rows.utc(from),
        to == null ? null : Rows.utc(to), to == null ? null : Rows.utc(to),
      ],
    );
    return [for (final row in rows) Rows.blockedPeriod(row)];
  }

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) async {
    await _db.query(
      'INSERT INTO blocked_periods (field_id, start_time, end_time, reason) VALUES (?, ?, ?, ?)',
      [period.fieldId.value, Rows.utc(period.startTime), Rows.utc(period.endTime), period.reason],
    );
    return BlockedPeriod(
      fieldId: period.fieldId,
      startTime: Rows.utc(period.startTime),
      endTime: Rows.utc(period.endTime),
      reason: period.reason,
    );
  }
}

final class MySqlUserRepository implements UserRepository {
  final SqlExecutor _db;

  MySqlUserRepository(this._db);

  @override
  Future<AppUser?> getUserById(UserId id) async {
    final rows = await _db.query('SELECT ${Rows.userColumns} FROM users u WHERE u.id = ?', [id.value]);
    return rows.isEmpty ? null : Rows.user(rows.first);
  }

  @override
  Future<AppUser?> getUserByEmail(String email) async {
    final rows = await _db.query(
      'SELECT ${Rows.userColumns} FROM users u WHERE u.email = ?',
      [email.trim()],
    );
    return rows.isEmpty ? null : Rows.user(rows.first);
  }

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    final rows = await _db.query(
      'SELECT ${Rows.userColumns} FROM users u WHERE (? IS NULL OR u.role = ?) '
      'ORDER BY u.last_name, u.first_name, u.id',
      [role?.name, role?.name],
    );
    return [for (final row in rows) Rows.user(row)];
  }
}
