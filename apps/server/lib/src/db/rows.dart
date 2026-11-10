import 'package:domain/domain.dart';
import 'package:mysql1/mysql1.dart';

abstract final class Rows {
  static const reservationColumns =
      'r.id, r.field_id, r.user_id, r.start_time, r.end_time, r.total_price, '
      'r.status, r.payment_status, r.checked_in_at, r.cancellation_reason, r.created_at';

  static const fieldColumns =
      'f.id, f.owner_id, f.name, f.description, f.sport, f.address, f.city, '
      'f.price_per_hour, f.contact_phone, f.confirmation_mode, f.is_active, '
      'f.approval_status, f.rejection_reason, '
      "(SELECT GROUP_CONCAT(i.url ORDER BY i.position SEPARATOR '\\n') "
      'FROM field_images i WHERE i.field_id = f.id) AS image_urls';

  static const userColumns =
      'u.id, u.first_name, u.last_name, u.email, u.phone_number, u.date_of_birth, '
      'u.role, u.created_at';

  static Reservation reservation(ResultRow row) => Reservation(
        id: ReservationId(_int(row['id'])),
        fieldId: FieldId(_int(row['field_id'])),
        userId: UserId(_int(row['user_id'])),
        startTime: _dateTime(row['start_time']),
        endTime: _dateTime(row['end_time']),
        totalPrice: _int(row['total_price']),
        status: ReservationStatus.values.byName(_string(row['status'])),
        paymentStatus: PaymentStatus.values.byName(_string(row['payment_status'])),
        checkedInAt: _nullableDateTime(row['checked_in_at']),
        cancellationReason: _nullableString(row['cancellation_reason']),
        createdAt: _dateTime(row['created_at']),
      );

  static SportsField field(ResultRow row) {
    final images = _nullableString(row['image_urls']);
    return SportsField(
      id: FieldId(_int(row['id'])),
      ownerId: UserId(_int(row['owner_id'])),
      name: _string(row['name']),
      description: _string(row['description']),
      sport: SportType.values.byName(_string(row['sport'])),
      address: _string(row['address']),
      city: _string(row['city']),
      pricePerHour: _int(row['price_per_hour']),
      contactPhone: _string(row['contact_phone']),
      imageUrls: images == null || images.isEmpty ? const [] : images.split('\n'),
      confirmationMode: ConfirmationMode.values.byName(_string(row['confirmation_mode'])),
      isActive: _bool(row['is_active']),
      approvalStatus: ApprovalStatus.values.byName(_string(row['approval_status'])),
      rejectionReason: _nullableString(row['rejection_reason']),
    );
  }

  static FieldSchedule schedule(ResultRow row) => FieldSchedule(
        fieldId: FieldId(_int(row['field_id'])),
        dayOfWeek: WeekDay.values.byName(_string(row['day_of_week'])),
        opensAt: _timeOfDay(row['opens_at']),
        closesAt: _timeOfDay(row['closes_at']),
        isOpen: _bool(row['is_open']),
      );

  static BlockedPeriod blockedPeriod(ResultRow row) => BlockedPeriod(
        fieldId: FieldId(_int(row['field_id'])),
        startTime: _dateTime(row['start_time']),
        endTime: _dateTime(row['end_time']),
        reason: _nullableString(row['reason']),
      );

  static AppUser user(ResultRow row) => AppUser(
        id: UserId(_int(row['id'])),
        firstName: _string(row['first_name']),
        lastName: _string(row['last_name']),
        email: _string(row['email']),
        phoneNumber: _string(row['phone_number']),
        dateOfBirth: _dateTime(row['date_of_birth']),
        role: UserRole.values.byName(_string(row['role'])),
        createdAt: _dateTime(row['created_at']),
      );

  static String time(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';

  static DateTime utc(DateTime value) => value.toUtc();

  static int _int(Object? value) => switch (value) {
        final int v => v,
        final num v => v.toInt(),
        final String v => int.parse(v),
        _ => throw FormatException('Očekivan broj, dobijeno $value'),
      };

  static bool _bool(Object? value) => switch (value) {
        final bool v => v,
        final int v => v != 0,
        _ => throw FormatException('Očekivana logička vrednost, dobijeno $value'),
      };

  static String _string(Object? value) => switch (value) {
        final String v => v,
        final Blob v => v.toString(),
        _ => throw FormatException('Očekivan tekst, dobijeno $value'),
      };

  static String? _nullableString(Object? value) => value == null ? null : _string(value);

  static DateTime _dateTime(Object? value) => switch (value) {
        final DateTime v => v.toUtc(),
        _ => throw FormatException('Očekivano vreme, dobijeno $value'),
      };

  static DateTime? _nullableDateTime(Object? value) => value == null ? null : _dateTime(value);

  static TimeOfDay _timeOfDay(Object? value) => switch (value) {
        final Duration v => TimeOfDay(hour: v.inHours, minute: v.inMinutes % 60),
        final String v => TimeOfDay(
            hour: int.parse(v.substring(0, 2)),
            minute: int.parse(v.substring(3, 5)),
          ),
        _ => throw FormatException('Očekivano vreme u danu, dobijeno $value'),
      };
}
