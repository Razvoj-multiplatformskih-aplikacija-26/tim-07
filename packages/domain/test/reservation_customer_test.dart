import 'package:domain/domain.dart';
import 'package:test/test.dart';

final ana = AppUser(
  id: const UserId(4),
  firstName: 'Ana',
  lastName: 'Anić',
  email: 'ana@example.com',
  phoneNumber: '0641111111',
  dateOfBirth: DateTime(1999),
  role: UserRole.user,
  createdAt: DateTime(2026),
);

final reservation = Reservation(
  id: const ReservationId(1),
  fieldId: const FieldId(2),
  userId: const UserId(4),
  startTime: DateTime(2026, 12, 1, 10),
  endTime: DateTime(2026, 12, 1, 11),
  totalPrice: 3000,
  status: ReservationStatus.pending,
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  group('podaci o korisniku uz rezervaciju', () {
    test('podrazumevano ih nema: ima samo identifikator korisnika', () {
      expect(reservation.customer, isNull);
      expect(reservation.userId, ana.id);
    });

    test('withCustomer dodaje korisnika i ne menja ostalo', () {
      final seen = reservation.withCustomer(ana);

      expect(seen.customer?.fullName, 'Ana Anić');
      expect(seen.id, reservation.id);
      expect(seen.status, reservation.status);
      expect(seen.startTime, reservation.startTime);
      expect(reservation.customer, isNull);
    });

    test('promena stanja ne gubi korisnika', () {
      final confirmed = reservation
          .withCustomer(ana)
          .copyWith(status: ReservationStatus.confirmed);

      expect(confirmed.customer, same(ana));
      expect(confirmed.status, ReservationStatus.confirmed);
    });

    test('withCustomer(null) skida korisnika', () {
      expect(reservation.withCustomer(ana).withCustomer(null).customer, isNull);
    });
  });
}
