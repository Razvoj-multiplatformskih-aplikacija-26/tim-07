import 'package:domain/domain.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);
const otherField = FieldId(4);

final now = DateTime(2026, 11, 19, 12);

Reservation reservation({
  FieldId field = fieldId,
  required int startHour,
  int hours = 1,
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: const ReservationId(1),
  fieldId: field,
  userId: const UserId(2),
  startTime: DateTime(2026, 11, 20, startHour),
  endTime: DateTime(2026, 11, 20, startHour + hours),
  totalPrice: 1000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

BlockedPeriodError? check({
  DateTime? start,
  DateTime? end,
  Iterable<Reservation> reservations = const [],
  DateTime? at,
}) => validateBlockedPeriod(
  fieldId: fieldId,
  startTime: start ?? DateTime(2026, 11, 20, 10),
  endTime: end ?? DateTime(2026, 11, 20, 12),
  now: at ?? now,
  reservations: reservations,
);

void main() {
  group('validateBlockedPeriod', () {
    test('blokada budućeg perioda bez rezervacija je dozvoljena', () {
      expect(check(), isNull);
    });

    test('kraj mora biti posle početka', () {
      expect(
        check(
          start: DateTime(2026, 11, 20, 12),
          end: DateTime(2026, 11, 20, 12),
        ),
        isA<InvalidBlockRange>(),
      );
      expect(
        check(
          start: DateTime(2026, 11, 20, 12),
          end: DateTime(2026, 11, 20, 10),
        ),
        isA<InvalidBlockRange>(),
      );
    });

    test('blokada cela u prošlosti nije dozvoljena', () {
      expect(
        check(
          start: DateTime(2026, 11, 18, 10),
          end: DateTime(2026, 11, 18, 12),
        ),
        isA<BlockInPast>(),
      );
      // Kraj tačno "sada" ne blokira ništa.
      expect(
        check(start: DateTime(2026, 11, 19, 10), end: now),
        isA<BlockInPast>(),
      );
    });

    test('period koji je već počeo, a traje, može da se blokira', () {
      expect(
        check(
          start: DateTime(2026, 11, 19, 10),
          end: DateTime(2026, 11, 19, 14),
        ),
        isNull,
      );
    });

    test('pogrešan raspon se prijavljuje pre prošlosti', () {
      expect(
        check(
          start: DateTime(2026, 11, 18, 12),
          end: DateTime(2026, 11, 18, 10),
        ),
        isA<InvalidBlockRange>(),
      );
    });

    test('ne sme preko potvrđene rezervacije', () {
      expect(
        check(reservations: [reservation(startHour: 11)]),
        isA<BlockOverlapsConfirmedReservation>(),
      );
    });

    test('dodir ivicom nije preklapanje', () {
      // Blokada 10-12, rezervacija 12-13 i 9-10.
      expect(
        check(
          reservations: [reservation(startHour: 12), reservation(startHour: 9)],
        ),
        isNull,
      );
    });

    test('rezervacija koja samo zadire u blokadu smeta', () {
      expect(
        check(reservations: [reservation(startHour: 11, hours: 3)]),
        isA<BlockOverlapsConfirmedReservation>(),
      );
      expect(
        check(reservations: [reservation(startHour: 8, hours: 3)]),
        isA<BlockOverlapsConfirmedReservation>(),
      );
    });

    test('rezervacija koja je cela unutar blokade smeta', () {
      expect(
        check(
          start: DateTime(2026, 11, 20, 8),
          end: DateTime(2026, 11, 20, 20),
          reservations: [reservation(startHour: 11)],
        ),
        isA<BlockOverlapsConfirmedReservation>(),
      );
    });

    test('rezervacija na čekanju ne smeta, vlasnik je može odbiti', () {
      expect(
        check(
          reservations: [
            reservation(startHour: 11, status: ReservationStatus.pending),
          ],
        ),
        isNull,
      );
    });

    test('otkazana i završena rezervacija ne smetaju', () {
      expect(
        check(
          reservations: [
            reservation(startHour: 10, status: ReservationStatus.cancelled),
            reservation(startHour: 11, status: ReservationStatus.completed),
          ],
        ),
        isNull,
      );
    });

    test('potvrđena rezervacija na drugom terenu ne smeta', () {
      expect(
        check(reservations: [reservation(field: otherField, startHour: 11)]),
        isNull,
      );
    });

    test('poruke su na srpskom i nisu prazne', () {
      expect(
        const InvalidBlockRange().message,
        'Kraj blokade mora biti posle početka.',
      );
      expect(
        const BlockInPast().message,
        'Blokada mora da obuhvata budući termin.',
      );
      expect(
        const BlockOverlapsConfirmedReservation().message,
        'U izabranom periodu već postoji potvrđena rezervacija.',
      );
    });
  });

  group('blokada i nove rezervacije', () {
    test('posle blokade pravilo rezervisanja odbija termin u njoj', () {
      final block = BlockedPeriod(
        id: const BlockedPeriodId(1),
        fieldId: fieldId,
        startTime: DateTime(2026, 11, 20, 10),
        endTime: DateTime(2026, 11, 20, 12),
        reason: 'Održavanje',
      );
      final schedules = [
        FieldSchedule(
          fieldId: fieldId,
          dayOfWeek: WeekDay.friday,
          opensAt: const TimeOfDay(hour: 8, minute: 0),
          closesAt: const TimeOfDay(hour: 23, minute: 0),
        ),
      ];

      ReservationValidationError? book(int hour) => validateReservationSlot(
        fieldId: fieldId,
        userId: const UserId(9),
        startTime: DateTime(2026, 11, 20, hour),
        endTime: DateTime(2026, 11, 20, hour + 1),
        now: now,
        existingReservations: const [],
        schedules: schedules,
        blockedPeriods: [block],
      );

      expect(book(10), isA<FieldBlocked>());
      expect(book(11), isA<FieldBlocked>());
      expect(book(12), isNull);
      expect(book(9), isNull);
    });

    test('blokada ima identifikator tek kada je sačuvana', () {
      final draft = BlockedPeriod(
        fieldId: fieldId,
        startTime: DateTime(2026, 11, 20, 10),
        endTime: DateTime(2026, 11, 20, 12),
      );

      expect(draft.id, isNull);
    });
  });
}
