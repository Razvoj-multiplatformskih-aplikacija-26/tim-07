
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

  group('Dozvoljeni prelazi statusa', () {
    test('pending moze da predje u confirmed', () {
      expect(
        canTransitionReservationStatus(
          ReservationStatus.pending,
          ReservationStatus.confirmed,
        ),
        isTrue,
      );
    });

    test('pending ne moze direktno u completed', () {
      expect(
        canTransitionReservationStatus(
          ReservationStatus.pending,
          ReservationStatus.completed,
        ),
        isFalse,
      );
    });

    test('confirmed moze da predje u cancelled', () {
      expect(
        canTransitionReservationStatus(
          ReservationStatus.confirmed,
          ReservationStatus.cancelled,
        ),
        isTrue,
      );
    });

    test('completed i cancelled su konacna stanja', () {
      for (final status in [
        ReservationStatus.completed,
        ReservationStatus.cancelled,
      ]) {
        for (final target in ReservationStatus.values) {
          expect(
            canTransitionReservationStatus(status, target),
            isFalse,
          );
        }
      }
    });
  });

  group('Automatski statusi', () {
    test('confirmed ostaje confirmed pre roka za check-in', () {
      final reservation = createReservation();

      expect(
        resolveReservationStatus(
          reservation,
          DateTime(2026, 11, 10, 12, 59),
        ),
        ReservationStatus.confirmed,
      );
    });

    test('bez check-in-a otkazuje se 5 sati pre pocetka', () {
      final reservation = createReservation();

      expect(
        resolveReservationStatus(
          reservation,
          DateTime(2026, 11, 10, 13),
        ),
        ReservationStatus.cancelled,
      );
    });

    test('pending se otkazuje kada istekne rok', () {
      final reservation = createReservation(
        status: ReservationStatus.pending,
      );

      expect(
        resolveReservationStatus(
          reservation,
          DateTime(2026, 11, 10, 13),
        ),
        ReservationStatus.cancelled,
      );
    });

    test('validan check-in cuva potvrđenu rezervaciju', () {
      final reservation = createReservation(
        checkedInAt: DateTime(2026, 11, 10, 10),
      );

      expect(
        hasValidCheckIn(reservation),
        isTrue,
      );

      expect(
        resolveReservationStatus(
          reservation,
          DateTime(2026, 11, 10, 19),
        ),
        ReservationStatus.confirmed,
      );
    });

    test('rezervacija se zavrsava nakon kraja termina', () {
      final reservation = createReservation(
        checkedInAt: DateTime(2026, 11, 10, 10),
      );

      expect(
        resolveReservationStatus(reservation, end),
        ReservationStatus.completed,
      );
    });

    test('zakasneli check-in nije validan', () {
      final reservation = createReservation(
        checkedInAt: DateTime(2026, 11, 10, 14),
      );

      expect(hasValidCheckIn(reservation), isFalse);

      expect(
        resolveReservationStatus(reservation, end),
        ReservationStatus.cancelled,
      );
    });
  });
}
