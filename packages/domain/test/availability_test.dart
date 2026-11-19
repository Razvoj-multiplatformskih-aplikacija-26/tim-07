import 'package:domain/domain.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);
const otherField = FieldId(4);

// Petak 20. 11. 2026. (petak je WeekDay.friday).
final friday = DateTime(2026, 11, 20);

FieldSchedule schedule({
  FieldId id = fieldId,
  WeekDay day = WeekDay.friday,
  int opens = 8,
  int closes = 23,
  bool isOpen = true,
}) => FieldSchedule(
  fieldId: id,
  dayOfWeek: day,
  opensAt: TimeOfDay(hour: opens, minute: 0),
  closesAt: TimeOfDay(hour: closes, minute: 0),
  isOpen: isOpen,
);

Reservation reservation({
  FieldId field = fieldId,
  int userId = 2,
  required DateTime start,
  Duration length = const Duration(hours: 1),
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: const ReservationId(1),
  fieldId: field,
  userId: UserId(userId),
  startTime: start,
  endTime: start.add(length),
  totalPrice: 1000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

// Sat pre prvog termina, pa su svi termini u budućnosti.
final earlyMorning = DateTime(2026, 11, 20, 7);

List<AvailabilitySlot> slots({
  Iterable<FieldSchedule>? schedules,
  Iterable<Reservation> reservations = const [],
  Iterable<BlockedPeriod> blocked = const [],
  DateTime? now,
  DateTime? date,
  Duration slotLength = const Duration(hours: 1),
}) => calculateAvailability(
  fieldId: fieldId,
  date: date ?? friday,
  schedules: schedules ?? [schedule()],
  reservations: reservations,
  blockedPeriods: blocked,
  now: now ?? earlyMorning,
  slotLength: slotLength,
);

List<SlotState> states(List<AvailabilitySlot> slots) => [
  for (final slot in slots) slot.state,
];

int hour(DateTime time) => time.hour;

void main() {
  group('termini iz radnog vremena', () {
    test('sat po sat od otvaranja do zatvaranja', () {
      final result = slots();

      expect(result, hasLength(15));
      expect(result.first.startTime, DateTime(2026, 11, 20, 8));
      expect(result.first.endTime, DateTime(2026, 11, 20, 9));
      expect(result.last.startTime, DateTime(2026, 11, 20, 22));
      expect(result.last.endTime, DateTime(2026, 11, 20, 23));
      expect(
        result.every((s) => s.duration == const Duration(hours: 1)),
        isTrue,
      );
    });

    test('termini idu jedan za drugim, bez rupa i preklapanja', () {
      final result = slots();

      for (var i = 1; i < result.length; i++) {
        expect(result[i].startTime, result[i - 1].endTime);
      }
    });

    test('kraće radno vreme daje manje termina (nema fiksne liste)', () {
      final result = slots(schedules: [schedule(opens: 10, closes: 13)]);

      expect(result.map((s) => hour(s.startTime)), [10, 11, 12]);
    });

    test('ostatak koji ne stane u ceo termin se izostavlja', () {
      final result = slots(
        schedules: [
          FieldSchedule(
            fieldId: fieldId,
            dayOfWeek: WeekDay.friday,
            opensAt: const TimeOfDay(hour: 8, minute: 0),
            closesAt: const TimeOfDay(hour: 10, minute: 30),
          ),
        ],
      );

      expect(result, hasLength(2));
      expect(result.last.endTime, DateTime(2026, 11, 20, 10));
    });

    test('termin od pola sata', () {
      final result = slots(
        schedules: [schedule(opens: 8, closes: 10)],
        slotLength: const Duration(minutes: 30),
      );

      expect(result, hasLength(4));
      expect(result[1].startTime, DateTime(2026, 11, 20, 8, 30));
    });

    test(
      'neradni dan, dan bez rasporeda i pogrešan raspored daju praznu listu',
      () {
        expect(slots(schedules: [schedule(isOpen: false)]), isEmpty);
        expect(slots(schedules: [schedule(day: WeekDay.monday)]), isEmpty);
        expect(slots(schedules: const []), isEmpty);
        expect(slots(schedules: [schedule(opens: 12, closes: 12)]), isEmpty);
        expect(slots(schedules: [schedule(opens: 20, closes: 8)]), isEmpty);
      },
    );

    test('raspored drugog terena se ne računa', () {
      expect(slots(schedules: [schedule(id: otherField)]), isEmpty);
    });

    test('dan u nedelji određuje raspored', () {
      final monday = DateTime(2026, 11, 23);
      final schedules = [
        schedule(day: WeekDay.friday, opens: 8, closes: 23),
        schedule(day: WeekDay.monday, opens: 9, closes: 12),
      ];

      expect(slots(schedules: schedules, date: monday), hasLength(3));
      expect(slots(schedules: schedules), hasLength(15));
    });

    test('UTC dan daje UTC termine', () {
      final result = slots(
        date: DateTime.utc(2026, 11, 20),
        now: DateTime.utc(2026, 11, 20, 7),
      );

      expect(result.first.startTime, DateTime.utc(2026, 11, 20, 8));
      expect(result.first.startTime.isUtc, isTrue);
    });

    test('nulta dužina termina nije dozvoljena', () {
      expect(
        () => slots(slotLength: Duration.zero),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('stanje termina', () {
    test('bez rezervacija i blokada svi su slobodni', () {
      expect(states(slots()).toSet(), {SlotState.free});
    });

    test('termin koji je počeo ili prošao je past', () {
      final result = slots(now: DateTime(2026, 11, 20, 10, 30));

      // 08, 09 i 10 (počeo u 10:00) su prošli; od 11 su slobodni.
      expect(states(result).take(4), [
        SlotState.past,
        SlotState.past,
        SlotState.past,
        SlotState.free,
      ]);
    });

    test(
      'termin koji počinje tačno sada je past, kao u pravilu rezervisanja',
      () {
        final result = slots(now: DateTime(2026, 11, 20, 12));

        expect(result[4].startTime, DateTime(2026, 11, 20, 12));
        expect(result[4].state, SlotState.past);
        expect(result[5].state, SlotState.free);
      },
    );

    test('rezervacija na čekanju i potvrđena zauzimaju termin', () {
      final result = slots(
        reservations: [
          reservation(
            start: DateTime(2026, 11, 20, 10),
            status: ReservationStatus.pending,
          ),
          reservation(
            start: DateTime(2026, 11, 20, 14),
            status: ReservationStatus.confirmed,
          ),
        ],
      );

      expect(result[2].state, SlotState.taken);
      expect(result[6].state, SlotState.taken);
      expect(result[3].state, SlotState.free);
    });

    test('otkazana i završena rezervacija ne zauzimaju termin', () {
      final result = slots(
        reservations: [
          reservation(
            start: DateTime(2026, 11, 20, 10),
            status: ReservationStatus.cancelled,
          ),
          reservation(
            start: DateTime(2026, 11, 20, 12),
            status: ReservationStatus.completed,
          ),
        ],
      );

      expect(states(result).toSet(), {SlotState.free});
    });

    test('rezervacija bilo kog korisnika zauzima termin', () {
      final result = slots(
        reservations: [
          reservation(userId: 7, start: DateTime(2026, 11, 20, 10)),
          reservation(userId: 8, start: DateTime(2026, 11, 20, 11)),
        ],
      );

      expect(result[2].state, SlotState.taken);
      expect(result[3].state, SlotState.taken);
    });

    test('rezervacija na drugom terenu ne zauzima ovaj teren', () {
      final result = slots(
        reservations: [
          reservation(field: otherField, start: DateTime(2026, 11, 20, 10)),
        ],
      );

      expect(states(result).toSet(), {SlotState.free});
    });

    test('rezervacija od sat i po zauzima oba termina koja dotiče', () {
      final result = slots(
        reservations: [
          reservation(
            start: DateTime(2026, 11, 20, 10, 30),
            length: const Duration(minutes: 90),
          ),
        ],
      );

      // 10:30-12:00 dotiče termine 10-11 i 11-12, ne i 12-13.
      expect(result[2].state, SlotState.taken);
      expect(result[3].state, SlotState.taken);
      expect(result[4].state, SlotState.free);
      expect(result[1].state, SlotState.free);
    });

    test(
      'rezervacija koja se završava tačno kad termin počinje ga ne zauzima',
      () {
        final result = slots(
          reservations: [reservation(start: DateTime(2026, 11, 20, 10))],
        );

        expect(result[1].state, SlotState.free);
        expect(result[2].state, SlotState.taken);
        expect(result[3].state, SlotState.free);
      },
    );

    test('blokada terena daje blocked, blokada drugog terena ne', () {
      final result = slots(
        blocked: [
          BlockedPeriod(
            fieldId: fieldId,
            startTime: DateTime(2026, 11, 20, 12),
            endTime: DateTime(2026, 11, 20, 14),
            reason: 'Održavanje',
          ),
          BlockedPeriod(
            fieldId: otherField,
            startTime: DateTime(2026, 11, 20, 16),
            endTime: DateTime(2026, 11, 20, 18),
          ),
        ],
      );

      expect(result[4].state, SlotState.blocked);
      expect(result[5].state, SlotState.blocked);
      expect(result[6].state, SlotState.free);
      expect(result[8].state, SlotState.free);
    });

    test('prioritet: past pre blocked, blocked pre taken', () {
      final result = slots(
        now: DateTime(2026, 11, 20, 9),
        reservations: [reservation(start: DateTime(2026, 11, 20, 8))],
        blocked: [
          BlockedPeriod(
            fieldId: fieldId,
            startTime: DateTime(2026, 11, 20, 12),
            endTime: DateTime(2026, 11, 20, 13),
          ),
        ],
      );
      final withBoth = slots(
        reservations: [reservation(start: DateTime(2026, 11, 20, 12))],
        blocked: [
          BlockedPeriod(
            fieldId: fieldId,
            startTime: DateTime(2026, 11, 20, 12),
            endTime: DateTime(2026, 11, 20, 13),
          ),
        ],
      );

      expect(result.first.state, SlotState.past);
      expect(withBoth[4].state, SlotState.blocked);
    });
  });

  group('slobodan termin je onaj koji pravilo rezervisanja propušta', () {
    test('isti odgovor za svaki termin dana', () {
      final reservations = [
        reservation(start: DateTime(2026, 11, 20, 10)),
        reservation(
          start: DateTime(2026, 11, 20, 15, 30),
          length: const Duration(minutes: 90),
        ),
      ];
      final blocked = [
        BlockedPeriod(
          fieldId: fieldId,
          startTime: DateTime(2026, 11, 20, 19),
          endTime: DateTime(2026, 11, 20, 21),
        ),
      ];
      final now = DateTime(2026, 11, 20, 9, 15);
      final schedules = [schedule()];

      final result = slots(
        reservations: reservations,
        blocked: blocked,
        now: now,
      );

      for (final slot in result) {
        final error = validateReservationSlot(
          fieldId: fieldId,
          userId: const UserId(99),
          startTime: slot.startTime,
          endTime: slot.endTime,
          now: now,
          existingReservations: reservations,
          schedules: schedules,
          blockedPeriods: blocked,
        );

        expect(
          slot.isFree,
          error == null,
          reason: '${slot.startTime} ${slot.state}',
        );
      }
      expect(result.where((s) => s.isFree), isNotEmpty);
      expect(result.where((s) => !s.isFree), isNotEmpty);
    });
  });
}
