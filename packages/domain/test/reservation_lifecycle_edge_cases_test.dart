
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 11, 10, 18);
  final end = DateTime(2026, 11, 10, 20);

  Reservation createReservation({
    ReservationStatus status = ReservationStatus.confirmed,
    DateTime? checkedInAt,
  }) {
    return Reservation(
      id: ReservationId(1),
      fieldId: FieldId(1),
      userId: UserId(1),
      startTime: start,
      endTime: end,
      totalPrice: 3000,
      status: status,
      checkedInAt: checkedInAt,
      createdAt: DateTime(2026, 11, 1),
    );
  }

  group('Granicni slucajevi automatskih statusa', () {
    test('check-in tacno 24 sata pre pocetka je validan', () {
      final reservation = createReservation(
        checkedInAt: start.subtract(const Duration(hours: 24)),
      );

      expect(hasValidCheckIn(reservation), isTrue);
    });

    test('check-in tacno 5 sati pre pocetka nije validan', () {
      final reservation = createReservation(
        checkedInAt: start.subtract(const Duration(hours: 5)),
      );

      expect(hasValidCheckIn(reservation), isFalse);
    });

    test('check-in pre otvaranja prozora nije validan', () {
      final reservation = createReservation(
        checkedInAt: start.subtract(
          const Duration(hours: 24, minutes: 1),
        ),
      );

      expect(hasValidCheckIn(reservation), isFalse);
    });

    test('validan check-in cuva confirmed status nakon roka', () {
      final reservation = createReservation(
        checkedInAt: start.subtract(const Duration(hours: 6)),
      );

      expect(
        resolveReservationStatus(
          reservation,
          start.subtract(const Duration(hours: 4)),
        ),
        ReservationStatus.confirmed,
      );
    });

    test('completed status ostaje completed', () {
      final reservation = createReservation(
        status: ReservationStatus.completed,
      );

      expect(
        resolveReservationStatus(
          reservation,
          start.subtract(const Duration(days: 2)),
        ),
        ReservationStatus.completed,
      );
    });

    test('cancelled status ostaje cancelled', () {
      final reservation = createReservation(
        status: ReservationStatus.cancelled,
      );

      expect(
        resolveReservationStatus(reservation, end),
        ReservationStatus.cancelled,
      );
    });

    test('pending ostaje pending pre isteka roka', () {
      final reservation = createReservation(
        status: ReservationStatus.pending,
      );

      expect(
        resolveReservationStatus(
          reservation,
          start.subtract(const Duration(hours: 6)),
        ),
        ReservationStatus.pending,
      );
    });

    test('confirmed sa validnim check-in-om zavrsava se tacno na kraju', () {
      final reservation = createReservation(
        checkedInAt: start.subtract(const Duration(hours: 6)),
      );

      expect(
        resolveReservationStatus(reservation, end),
        ReservationStatus.completed,
      );
    });
  });
}

