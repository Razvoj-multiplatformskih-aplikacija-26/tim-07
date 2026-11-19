import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  AppUser user(UserRole role, {int id = 1}) => AppUser(
        id: UserId(id),
        firstName: 'A',
        lastName: 'B',
        email: 'a@b.rs',
        phoneNumber: '060',
        dateOfBirth: DateTime(2000),
        role: role,
        createdAt: DateTime(2026),
      );

  final start = DateTime(2030, 6, 4, 18);
  Reservation reservation(ReservationStatus status) => Reservation(
        id: const ReservationId(1),
        fieldId: const FieldId(1),
        userId: const UserId(1),
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        totalPrice: 3000,
        status: status,
        createdAt: DateTime(2030, 6, 1),
      );

  test('korisnik otkazuje najkasnije 5 sati pre početka', () {
    expect(
      validateCancellationBy(
          user: user(UserRole.user), reservation: reservation(ReservationStatus.confirmed), now: DateTime(2030, 6, 4, 12)),
      isNull,
    );
    expect(
      validateCancellationBy(
          user: user(UserRole.user), reservation: reservation(ReservationStatus.confirmed), now: DateTime(2030, 6, 4, 14)),
      isA<CancellationDeadlineExpired>(),
    );
  });

  test('vlasnik i administrator otkazuju do početka termina', () {
    for (final role in [UserRole.owner, UserRole.admin]) {
      expect(
        validateCancellationBy(
            user: user(role, id: 3), reservation: reservation(ReservationStatus.confirmed), now: DateTime(2030, 6, 4, 17)),
        isNull,
      );
      expect(
        validateCancellationBy(user: user(role, id: 3), reservation: reservation(ReservationStatus.confirmed), now: start),
        isA<CancellationDeadlineExpired>(),
      );
    }
  });

  test('završena i otkazana se ne otkazuju ni od strane osoblja', () {
    for (final status in [ReservationStatus.completed, ReservationStatus.cancelled]) {
      expect(
        validateCancellationBy(
            user: user(UserRole.owner, id: 3), reservation: reservation(status), now: DateTime(2030, 6, 1)),
        isA<InvalidReservationStatus>(),
      );
    }
  });
}
