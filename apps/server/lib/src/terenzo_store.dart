import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

const exclusionViolation = '23P01';
const _active = "status IN ('pending', 'confirmed')";

const _fieldColumns = '''
  f.id, f.owner_id, f.name, f.description, f.sport, f.address, f.city, f.price_per_hour,
  f.contact_phone, f.confirmation_mode, f.is_active, f.approval_status, f.rejection_reason,
  coalesce((SELECT array_agg(i.url ORDER BY i.position) FROM field_images i WHERE i.field_id = f.id), '{}') AS image_urls
''';

const _reservationColumns = '''
  r.id, r.field_id, r.user_id, r.start_time, r.end_time, r.total_price, r.status, r.payment_status,
  r.checked_in_at, r.cancellation_reason, r.created_at
''';

const _userColumns =
    'u.id, u.first_name, u.last_name, u.email, u.phone_number, u.date_of_birth, u.role, u.created_at, u.is_active';

typedef Account = ({AppUser user, String passwordHash});

final class TerenzoStore {
  const TerenzoStore(this._database);

  final Session _database;

  TerenzoStore within(Session session) => TerenzoStore(session);

  Future<bool> isEmpty() async {
    final rows = await _database.execute('SELECT count(*) FROM users');
    return rows.single[0] == 0;
  }

  Future<AppUser?> user(UserId id) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_userColumns FROM users u WHERE u.id = @id'),
      parameters: {'id': id.value},
    );
    return rows.isEmpty ? null : _user(rows.single.toColumnMap());
  }

  Future<Account?> account(String email) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_userColumns, u.password_hash FROM users u WHERE lower(u.email) = lower(@email)'),
      parameters: {'email': email.trim()},
    );
    if (rows.isEmpty) return null;
    final row = rows.single.toColumnMap();
    return (user: _user(row), passwordHash: row['password_hash']! as String);
  }

  Future<List<AppUser>> users({UserRole? role}) async {
    final rows = await _database.execute(
      Sql.named(
        'SELECT $_userColumns FROM users u WHERE @role::text IS NULL OR u.role = @role::text '
        'ORDER BY u.last_name, u.first_name, u.id',
      ),
      parameters: {'role': role?.name},
    );
    return [for (final row in rows) _user(row.toColumnMap())];
  }

  /// Menja stanje naloga i vraća ga; `null` kada takvog naloga nema.
  Future<AppUser?> setUserActive(UserId id, {required bool active}) async {
    final rows = await _database.execute(
      Sql.named('UPDATE users SET is_active = @active WHERE id = @id RETURNING id'),
      parameters: {'id': id.value, 'active': active},
    );
    return rows.isEmpty ? null : user(id);
  }

  Future<UserId> insertUser({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required DateTime dateOfBirth,
    required UserRole role,
    required String passwordHash,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
        INSERT INTO users (first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
        VALUES (@first, @last, @email, @phone, @born::date, @role, @hash)
        RETURNING id
      '''),
      parameters: {
        'first': firstName,
        'last': lastName,
        'email': email,
        'phone': phoneNumber,
        'born': _date(dateOfBirth),
        'role': role.name,
        'hash': passwordHash,
      },
    );
    return UserId(rows.single[0]! as int);
  }

  Future<List<SportsField>> fields() => _fields('TRUE', const {});

  Future<SportsField?> field(FieldId id) async {
    final found = await _fields('f.id = @id', {'id': id.value});
    return found.isEmpty ? null : found.single;
  }

  Future<SportsField?> fieldForUpdate(FieldId id) async {
    final locked = await _database.execute(
      Sql.named('SELECT id FROM sports_fields WHERE id = @id FOR UPDATE'),
      parameters: {'id': id.value},
    );
    return locked.isEmpty ? null : field(id);
  }

  Future<List<SportsField>> _fields(String where, Map<String, Object?> parameters) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_fieldColumns FROM sports_fields f WHERE $where ORDER BY f.name, f.id'),
      parameters: parameters,
    );
    return [for (final row in rows) _field(row.toColumnMap())];
  }

  Future<FieldId> insertField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    required ConfirmationMode confirmationMode,
    bool isActive = true,
    ApprovalStatus approvalStatus = ApprovalStatus.pending,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
        INSERT INTO sports_fields
          (owner_id, name, description, sport, address, city, price_per_hour, contact_phone, confirmation_mode,
           is_active, approval_status)
        VALUES (@owner, @name, @description, @sport, @address, @city, @price, @phone, @mode, @active, @approval)
        RETURNING id
      '''),
      parameters: {
        'owner': ownerId.value,
        'name': name,
        'description': description,
        'sport': sport.name,
        'address': address,
        'city': city,
        'price': pricePerHour,
        'phone': contactPhone,
        'mode': confirmationMode.name,
        'active': isActive,
        'approval': approvalStatus.name,
      },
    );
    return FieldId(rows.single[0]! as int);
  }

  Future<void> updateField(SportsField field, {required ApprovalStatus approvalStatus}) async {
    await _database.execute(
      Sql.named('''
        UPDATE sports_fields SET name = @name, description = @description, sport = @sport, address = @address,
          city = @city, price_per_hour = @price, contact_phone = @phone, confirmation_mode = @mode,
          is_active = @active, approval_status = @approval
        WHERE id = @id
      '''),
      parameters: {
        'id': field.id.value,
        'name': field.name,
        'description': field.description,
        'sport': field.sport.name,
        'address': field.address,
        'city': field.city,
        'price': field.pricePerHour,
        'phone': field.contactPhone,
        'mode': field.confirmationMode.name,
        'active': field.isActive,
        'approval': approvalStatus.name,
      },
    );
  }

  Future<void> replaceImages(FieldId id, List<String> urls) async {
    await _database.execute(Sql.named('DELETE FROM field_images WHERE field_id = @id'), parameters: {'id': id.value});
    for (var i = 0; i < urls.length; i++) {
      await _database.execute(
        Sql.named('INSERT INTO field_images (field_id, position, url) VALUES (@id, @position, @url)'),
        parameters: {'id': id.value, 'position': i, 'url': urls[i]},
      );
    }
  }

  Future<bool> review(
    FieldId id, {
    required ApprovalStatus from,
    required ApprovalStatus to,
    required UserId reviewer,
    required DateTime at,
    String? reason,
  }) async {
    final result = await _database.execute(
      Sql.named('''
        UPDATE sports_fields SET approval_status = @to, rejection_reason = @reason, reviewed_by = @reviewer,
          reviewed_at = @at
        WHERE id = @id AND approval_status = @from
      '''),
      parameters: {
        'id': id.value,
        'from': from.name,
        'to': to.name,
        'reason': to == ApprovalStatus.rejected ? reason : null,
        'reviewer': reviewer.value,
        'at': at.toUtc(),
      },
    );
    return result.affectedRows == 1;
  }

  Future<List<FieldSchedule>> schedules(Iterable<FieldId> fieldIds) async {
    final rows = await _database.execute(
      Sql.named('''
        SELECT field_id, day_of_week, to_char(opens_at, 'HH24:MI') AS opens_at, to_char(closes_at, 'HH24:MI') AS closes_at,
          is_open
        FROM field_schedules WHERE field_id = ANY(@ids)
      '''),
      parameters: {'ids': TypedValue(Type.integerArray, [for (final id in fieldIds) id.value])},
    );
    final schedules = [for (final row in rows) _schedule(row.toColumnMap())];
    schedules.sort((a, b) => a.dayOfWeek.index.compareTo(b.dayOfWeek.index));
    return schedules;
  }

  Future<void> replaceSchedules(FieldId fieldId, List<FieldSchedule> schedules) async {
    await _database.execute(
      Sql.named('DELETE FROM field_schedules WHERE field_id = @id'),
      parameters: {'id': fieldId.value},
    );
    for (final schedule in schedules) {
      await _database.execute(
        Sql.named('''
          INSERT INTO field_schedules (field_id, day_of_week, opens_at, closes_at, is_open)
          VALUES (@id, @day, @opens::time, @closes::time, @open)
        '''),
        parameters: {
          'id': fieldId.value,
          'day': schedule.dayOfWeek.name,
          'opens': _time(schedule.opensAt),
          'closes': _time(schedule.closesAt),
          'open': schedule.isOpen,
        },
      );
    }
  }

  Future<List<BlockedPeriod>> blockedPeriods(Iterable<FieldId> fieldIds, {DateTime? from, DateTime? to}) async {
    final rows = await _database.execute(
      Sql.named('''
        SELECT id, field_id, start_time, end_time, reason FROM blocked_periods
        WHERE field_id = ANY(@ids)
          AND (@from::timestamptz IS NULL OR end_time > @from::timestamptz)
          AND (@to::timestamptz IS NULL OR start_time < @to::timestamptz)
        ORDER BY start_time
      '''),
      parameters: {
        'ids': TypedValue(Type.integerArray, [for (final id in fieldIds) id.value]),
        'from': from?.toUtc(),
        'to': to?.toUtc(),
      },
    );
    return [for (final row in rows) _blocked(row.toColumnMap())];
  }

  Future<BlockedPeriod> insertBlockedPeriod(BlockedPeriod period) async {
    final rows = await _database.execute(
      Sql.named('''
        INSERT INTO blocked_periods (field_id, start_time, end_time, reason) VALUES (@field, @start, @end, @reason)
        RETURNING id, field_id, start_time, end_time, reason
      '''),
      parameters: {
        'field': period.fieldId.value,
        'start': period.startTime.toUtc(),
        'end': period.endTime.toUtc(),
        'reason': period.reason,
      },
    );
    return _blocked(rows.single.toColumnMap());
  }

  Future<bool> deleteBlockedPeriod(FieldId fieldId, BlockedPeriodId id) async {
    final result = await _database.execute(
      Sql.named('DELETE FROM blocked_periods WHERE id = @id AND field_id = @field'),
      parameters: {'id': id.value, 'field': fieldId.value},
    );
    return result.affectedRows == 1;
  }

  Future<List<Reservation>> reservations({UserId? userId, FieldId? fieldId}) => _reservations(
    '(@user::int IS NULL OR r.user_id = @user::int) AND (@field::int IS NULL OR r.field_id = @field::int)',
    {'user': userId?.value, 'field': fieldId?.value},
  );

  Future<List<Reservation>> reservationsOverlapping(
    Iterable<FieldId> fieldIds, {
    required DateTime from,
    required DateTime to,
  }) => _reservations(
    'r.field_id = ANY(@ids) AND tstzrange(r.start_time, r.end_time) && tstzrange(@from, @to)',
    {
      'ids': TypedValue(Type.integerArray, [for (final id in fieldIds) id.value]),
      'from': from.toUtc(),
      'to': to.toUtc(),
    },
  );

  Future<List<Reservation>> activeOverlapping({
    required FieldId fieldId,
    required UserId userId,
    required DateTime from,
    required DateTime to,
  }) => _reservations(
    'r.$_active AND (r.field_id = @field OR r.user_id = @user) '
    'AND tstzrange(r.start_time, r.end_time) && tstzrange(@from, @to)',
    {'field': fieldId.value, 'user': userId.value, 'from': from.toUtc(), 'to': to.toUtc()},
  );

  Future<List<Reservation>> activeStartingBefore(DateTime instant) =>
      _reservations('r.$_active AND r.start_time <= @at', {'at': instant.toUtc()});

  Future<Reservation?> find(ReservationId id) async {
    final found = await _reservations('r.id = @id', {'id': id.value});
    return found.isEmpty ? null : found.single;
  }

  Future<List<Reservation>> _reservations(String where, Map<String, Object?> parameters) async {
    final rows = await _database.execute(
      Sql.named('SELECT $_reservationColumns FROM reservations r WHERE $where ORDER BY r.start_time, r.id'),
      parameters: parameters,
    );
    return [for (final row in rows) _reservation(row.toColumnMap())];
  }

  Future<Reservation> insertReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
    required int totalPrice,
    required ReservationStatus status,
    required DateTime createdAt,
    DateTime? checkedInAt,
    String? cancellationReason,
  }) async {
    final rows = await _database.execute(
      Sql.named('''
        INSERT INTO reservations
          (field_id, user_id, start_time, end_time, total_price, status, checked_in_at, cancellation_reason, created_at)
        VALUES (@field, @user, @start, @end, @price, @status, @checkedIn, @reason, @created)
        RETURNING id
      '''),
      parameters: {
        'field': fieldId.value,
        'user': userId.value,
        'start': startTime.toUtc(),
        'end': endTime.toUtc(),
        'price': totalPrice,
        'status': status.name,
        'checkedIn': checkedInAt?.toUtc(),
        'reason': cancellationReason,
        'created': createdAt.toUtc(),
      },
    );
    return (await find(ReservationId(rows.single[0]! as int)))!;
  }

  Future<bool> changeStatus(
    ReservationId id, {
    required ReservationStatus from,
    required ReservationStatus to,
    String? reason,
  }) async {
    final result = await _database.execute(
      Sql.named('''
        UPDATE reservations SET status = @to, cancellation_reason = coalesce(@reason, cancellation_reason)
        WHERE id = @id AND status = @from
      '''),
      parameters: {'id': id.value, 'from': from.name, 'to': to.name, 'reason': reason},
    );
    return result.affectedRows == 1;
  }

  Future<bool> checkIn(ReservationId id, DateTime at) async {
    final result = await _database.execute(
      Sql.named('''
        UPDATE reservations SET checked_in_at = @at
        WHERE id = @id AND status = 'confirmed' AND checked_in_at IS NULL
      '''),
      parameters: {'id': id.value, 'at': at.toUtc()},
    );
    return result.affectedRows == 1;
  }
}

AppUser _user(Map<String, Object?> row) => AppUser(
  id: UserId(row['id']! as int),
  firstName: row['first_name']! as String,
  lastName: row['last_name']! as String,
  email: row['email']! as String,
  phoneNumber: row['phone_number']! as String,
  dateOfBirth: row['date_of_birth']! as DateTime,
  role: UserRole.values.byName(row['role']! as String),
  createdAt: row['created_at']! as DateTime,
  isActive: row['is_active']! as bool,
);

SportsField _field(Map<String, Object?> row) => SportsField(
  id: FieldId(row['id']! as int),
  ownerId: UserId(row['owner_id']! as int),
  name: row['name']! as String,
  description: row['description']! as String,
  sport: SportType.values.byName(row['sport']! as String),
  address: row['address']! as String,
  city: row['city']! as String,
  pricePerHour: row['price_per_hour']! as int,
  contactPhone: row['contact_phone']! as String,
  imageUrls: [for (final url in row['image_urls']! as List<Object?>) url! as String],
  confirmationMode: ConfirmationMode.values.byName(row['confirmation_mode']! as String),
  isActive: row['is_active']! as bool,
  approvalStatus: ApprovalStatus.values.byName(row['approval_status']! as String),
  rejectionReason: row['rejection_reason'] as String?,
);

FieldSchedule _schedule(Map<String, Object?> row) => FieldSchedule(
  fieldId: FieldId(row['field_id']! as int),
  dayOfWeek: WeekDay.values.byName(row['day_of_week']! as String),
  opensAt: _timeOfDay(row['opens_at']! as String),
  closesAt: _timeOfDay(row['closes_at']! as String),
  isOpen: row['is_open']! as bool,
);

BlockedPeriod _blocked(Map<String, Object?> row) => BlockedPeriod(
  id: BlockedPeriodId(row['id']! as int),
  fieldId: FieldId(row['field_id']! as int),
  startTime: row['start_time']! as DateTime,
  endTime: row['end_time']! as DateTime,
  reason: row['reason'] as String?,
);

Reservation _reservation(Map<String, Object?> row) => Reservation(
  id: ReservationId(row['id']! as int),
  fieldId: FieldId(row['field_id']! as int),
  userId: UserId(row['user_id']! as int),
  startTime: row['start_time']! as DateTime,
  endTime: row['end_time']! as DateTime,
  totalPrice: row['total_price']! as int,
  status: ReservationStatus.values.byName(row['status']! as String),
  paymentStatus: PaymentStatus.values.byName(row['payment_status']! as String),
  checkedInAt: row['checked_in_at'] as DateTime?,
  cancellationReason: row['cancellation_reason'] as String?,
  createdAt: row['created_at']! as DateTime,
);

TimeOfDay _timeOfDay(String value) =>
    TimeOfDay(hour: int.parse(value.substring(0, 2)), minute: int.parse(value.substring(3, 5)));

String _time(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
