
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

  group('Validacija termina rezervacije', () {
    test('ispravan termin prolazi', () {
      final result = validateReservationTime(
        startTime: start,
        endTime: end,
        now: DateTime(2026, 11, 9),
      );

      expect(result, isNull);
    });

    test('kraj pre pocetka nije dozvoljen', () {
      final result = validateReservationTime(
        startTime: start,
        endTime: start.subtract(const Duration(hours: 1)),
        now: DateTime(2026, 11, 9),
      );

      expect(result, isA<InvalidTimeRange>());
    });

    test('pocetak i kraj ne smeju biti isti', () {
      final result = validateReservationTime(
        startTime: start,
        endTime: start,
        now: DateTime(2026, 11, 9),
      );

      expect(result, isA<InvalidTimeRange>());
    });

    test('nije dozvoljena rezervacija u proslosti', () {
      final result = validateReservationTime(
        startTime: start,
        endTime: end,
        now: DateTime(2026, 11, 11),
      );

      expect(result, isA<ReservationInPast>());
    });
  });

  group('Validacija check-in-a', () {
    test('check-in tacno 24 sata pre pocetka je dozvoljen', () {
      final result = validateCheckIn(
        reservation: createReservation(),
        now: start.subtract(const Duration(hours: 24)),
      );

      expect(result, isNull);
    });

    test('check-in ranije od 24 sata nije dozvoljen', () {
      final result = validateCheckIn(
        reservation: createReservation(),
        now: start.subtract(
          const Duration(hours: 24, minutes: 1),
        ),
      );

      expect(result, isA<CheckInNotAllowed>());
    });

    test('check-in 6 sati pre pocetka je dozvoljen', () {
      final result = validateCheckIn(
        reservation: createReservation(),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isNull);
    });

    test('check-in tacno 5 sati pre pocetka nije dozvoljen', () {
      final result = validateCheckIn(
        reservation: createReservation(),
        now: start.subtract(const Duration(hours: 5)),
      );

      expect(result, isA<CheckInNotAllowed>());
    });

    test('pending rezervacija ne moze na check-in', () {
      final result = validateCheckIn(
        reservation: createReservation(
          status: ReservationStatus.pending,
        ),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isA<InvalidReservationStatus>());
    });

    test('nije dozvoljen ponovni check-in', () {
      final result = validateCheckIn(
        reservation: createReservation(
          checkedInAt: start.subtract(const Duration(hours: 6)),
        ),
        now: start.subtract(const Duration(hours: 5, minutes: 30)),
      );

      expect(result, isA<InvalidReservationStatus>());
    });
  });

  group('Validacija otkazivanja', () {
    test('pending rezervacija moze da se otkaze na vreme', () {
      final result = validateCancellation(
        reservation: createReservation(
          status: ReservationStatus.pending,
        ),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isNull);
    });

    test('confirmed rezervacija moze da se otkaze na vreme', () {
      final result = validateCancellation(
        reservation: createReservation(),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isNull);
    });

    test('otkazivanje tacno 5 sati pre pocetka nije dozvoljeno', () {
      final result = validateCancellation(
        reservation: createReservation(),
        now: start.subtract(const Duration(hours: 5)),
      );

      expect(result, isA<CancellationDeadlineExpired>());
    });

    test('completed rezervacija ne moze da se otkaze', () {
      final result = validateCancellation(
        reservation: createReservation(
          status: ReservationStatus.completed,
        ),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isA<InvalidReservationStatus>());
    });

    test('cancelled rezervacija ne moze ponovo da se otkaze', () {
      final result = validateCancellation(
        reservation: createReservation(
          status: ReservationStatus.cancelled,
        ),
        now: start.subtract(const Duration(hours: 6)),
      );

      expect(result, isA<InvalidReservationStatus>());
    });
  });
}
