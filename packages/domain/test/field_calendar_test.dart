import 'package:domain/domain.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);

/// Petak 20.11.2026.
final friday = DateTime(2026, 11, 20);
final now = DateTime(2026, 11, 10, 8);

FieldSchedule schedule({
  FieldId field = fieldId,
  WeekDay day = WeekDay.friday,
  int opens = 8,
  int closes = 12,
  bool isOpen = true,
}) => FieldSchedule(
  fieldId: field,
  dayOfWeek: day,
  opensAt: TimeOfDay(hour: opens, minute: 0),
  closesAt: TimeOfDay(hour: closes, minute: 0),
  isOpen: isOpen,
);

Reservation reservation({
  int id = 1,
  FieldId field = fieldId,
  required int startHour,
  int hours = 1,
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: ReservationId(id),
  fieldId: field,
  userId: const UserId(2),
  startTime: DateTime(2026, 11, 20, startHour),
  endTime: DateTime(2026, 11, 20, startHour + hours),
  totalPrice: 1000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

BlockedPeriod block({
  required int startHour,
  required int endHour,
  FieldId field = fieldId,
  String? reason,
}) => BlockedPeriod(
  id: const BlockedPeriodId(5),
  fieldId: field,
  startTime: DateTime(2026, 11, 20, startHour),
  endTime: DateTime(2026, 11, 20, endHour),
  reason: reason,
);

FieldCalendarDay day({
  DateTime? date,
  Iterable<FieldSchedule>? schedules,
  Iterable<Reservation> reservations = const [],
  Iterable<BlockedPeriod> blocks = const [],
  DateTime? at,
}) => buildFieldCalendarDay(
  fieldId: fieldId,
  date: date ?? friday,
  schedules: schedules ?? [schedule()],
  reservations: reservations,
  blockedPeriods: blocks,
  now: at ?? now,
);

String describe(CalendarEntry entry) {
  final range = '${entry.startTime.hour}-${entry.endTime.hour}';
  return switch (entry) {
    CalendarFreeSlot(:final isPast) => isPast ? 'past $range' : 'free $range',
    CalendarReservation(:final status) => '${status.name} $range',
    CalendarBlock() => 'block $range',
  };
}

List<String> described(FieldCalendarDay day) => [
  for (final entry in day.entries) describe(entry),
];

void main() {
  group('buildFieldCalendarDay', () {
    test('dan bez rezervacija i blokada je niz slobodnih termina', () {
      final result = day();

      expect(result.isOpen, isTrue);
      expect(described(result), [
        'free 8-9',
        'free 9-10',
        'free 10-11',
        'free 11-12',
      ]);
    });

    test('dan je ponoć, bez obzira na sat koji je prosleđen', () {
      final result = day(date: DateTime(2026, 11, 20, 17, 45));

      expect(result.date, friday);
    });

    test('neradni dan i dan bez rasporeda nemaju redove', () {
      final closed = day(schedules: [schedule(isOpen: false)]);
      final missing = day(schedules: [schedule(day: WeekDay.monday)]);
      final inverted = day(schedules: [schedule(opens: 12, closes: 8)]);

      for (final result in [closed, missing, inverted]) {
        expect(result.isOpen, isFalse);
        expect(result.entries, isEmpty);
      }
    });

    test('radno vreme drugog terena se ne koristi', () {
      final result = day(schedules: [schedule(field: const FieldId(9))]);

      expect(result.isOpen, isFalse);
    });

    test('rezervacija od više sati ulazi jednom, sa svojim opsegom', () {
      final result = day(
        reservations: [reservation(startHour: 9, hours: 2)],
      );

      expect(described(result), [
        'free 8-9',
        'confirmed 9-11',
        'free 11-12',
      ]);
    });

    test('stanje rezervacije se vidi: na čekanju, potvrđena, završena', () {
      final result = day(
        reservations: [
          reservation(id: 1, startHour: 8, status: ReservationStatus.pending),
          reservation(id: 2, startHour: 9),
          reservation(
            id: 3,
            startHour: 10,
            status: ReservationStatus.completed,
          ),
        ],
      );

      expect(described(result).take(3), [
        'pending 8-9',
        'confirmed 9-10',
        'completed 10-11',
      ]);
    });

    test('otkazana rezervacija ostavlja termin slobodan', () {
      final result = day(
        reservations: [
          reservation(startHour: 9, status: ReservationStatus.cancelled),
        ],
      );

      expect(described(result), everyElement(startsWith('free')));
    });

    test('rezervacija na čekanju kojoj je istekao rok se vidi kao slobodno', () {
      // Rok je pre početka; sat je posle roka, a pre početka termina.
      final late = DateTime(2026, 11, 20, 8, 30);
      final result = day(
        reservations: [
          reservation(startHour: 9, status: ReservationStatus.pending),
        ],
        at: late,
      );

      expect(described(result), [
        'past 8-9',
        'free 9-10',
        'free 10-11',
        'free 11-12',
      ]);
    });

    test('rezervacija drugog terena se ne vidi', () {
      final result = day(
        reservations: [reservation(startHour: 9, field: const FieldId(9))],
      );

      expect(described(result), everyElement(startsWith('free')));
    });

    test('blokada ulazi jednom, sa svojim opsegom i razlogom', () {
      final result = day(
        blocks: [block(startHour: 9, endHour: 11, reason: 'Održavanje')],
      );

      expect(described(result), ['free 8-9', 'block 9-11', 'free 11-12']);
      final entry = result.entries[1] as CalendarBlock;
      expect(entry.period.reason, 'Održavanje');
    });

    test('blokada koja počinje pre radnog vremena se vidi od otvaranja', () {
      final result = day(
        blocks: [
          BlockedPeriod(
            fieldId: fieldId,
            startTime: DateTime(2026, 11, 19, 20),
            endTime: DateTime(2026, 11, 20, 9),
          ),
        ],
      );

      expect(described(result).first, startsWith('block'));
      expect(described(result).skip(1), everyElement(startsWith('free')));
    });

    test('blokada drugog terena se ne vidi', () {
      final result = day(
        blocks: [block(startHour: 8, endHour: 12, field: const FieldId(9))],
      );

      expect(described(result), everyElement(startsWith('free')));
    });

    test('rezervacija na čekanju ispod blokade pripada rezervaciji', () {
      final result = day(
        reservations: [
          reservation(startHour: 9, status: ReservationStatus.pending),
        ],
        blocks: [block(startHour: 8, endHour: 12)],
      );

      expect(described(result), [
        'block 8-12',
        'pending 9-10',
      ]);
    });

    test('termin koji je već počeo je prošao, a budući je slobodan', () {
      final result = day(at: DateTime(2026, 11, 20, 9, 30));

      expect(described(result), [
        'past 8-9',
        'past 9-10',
        'free 10-11',
        'free 11-12',
      ]);
    });

    test('dužina termina se menja parametrom', () {
      final result = buildFieldCalendarDay(
        fieldId: fieldId,
        date: friday,
        schedules: [schedule()],
        reservations: const [],
        now: now,
        slotLength: const Duration(minutes: 30),
      );

      expect(result.entries, hasLength(8));
    });

    test('dužina termina mora biti bar minut', () {
      expect(
        () => buildFieldCalendarDay(
          fieldId: fieldId,
          date: friday,
          schedules: [schedule()],
          reservations: const [],
          now: now,
          slotLength: Duration.zero,
        ),
        throwsArgumentError,
      );
    });

    test('isti ulaz daje jednake dane', () {
      final first = day(reservations: [reservation(startHour: 9)]);
      final second = day(reservations: [reservation(startHour: 9)]);
      final other = day(reservations: [reservation(startHour: 10)]);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(other));
    });
  });
}
