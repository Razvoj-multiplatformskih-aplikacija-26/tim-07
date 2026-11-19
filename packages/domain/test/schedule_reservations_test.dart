import 'package:domain/domain.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);

// Četvrtak 19. 11. 2026. u podne; petak je 20. 11.
final now = DateTime(2026, 11, 19, 12);

FieldSchedule day(WeekDay weekday, {int opens = 8, int closes = 23, bool open = true}) =>
    FieldSchedule(
      fieldId: fieldId,
      dayOfWeek: weekday,
      opensAt: TimeOfDay(hour: opens, minute: 0),
      closesAt: TimeOfDay(hour: closes, minute: 0),
      isOpen: open,
    );

List<FieldSchedule> week({int opens = 8, int closes = 23}) => [
  for (final weekday in WeekDay.values) day(weekday, opens: opens, closes: closes),
];

Reservation reservation(
  int id, {
  FieldId field = fieldId,
  required DateTime start,
  int hours = 1,
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: ReservationId(id),
  fieldId: field,
  userId: const UserId(1),
  startTime: start,
  endTime: start.add(Duration(hours: hours)),
  totalPrice: 3000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

DateTime friday(int hour) => DateTime(2026, 11, 20, hour);

ScheduleConflictsWithReservations? check(
  List<FieldSchedule> schedules,
  List<Reservation> reservations,
) => validateScheduleAgainstReservations(
      fieldId: fieldId,
      schedules: schedules,
      reservations: reservations,
      now: now,
    ) as ScheduleConflictsWithReservations?;

void main() {
  group('promena radnog vremena preko postojećih rezervacija', () {
    test('rezervacija u novom radnom vremenu ne smeta', () {
      expect(check(week(opens: 10, closes: 20), [reservation(1, start: friday(15))]), isNull);
    });

    test('rezervacija u 15 kada teren više ne radi u 15 je sukob', () {
      // Novo radno vreme: 08-14.
      final conflict = check(week(opens: 8, closes: 14), [reservation(1, start: friday(15))]);

      expect(conflict, isNotNull);
      expect(conflict!.count, 1);
      expect(conflict.firstStart, friday(15));
      expect(conflict.day, WeekDay.friday);
    });

    test('važi i za rezervaciju na čekanju', () {
      final conflict = check(
        week(opens: 8, closes: 14),
        [reservation(1, start: friday(15), status: ReservationStatus.pending)],
      );

      expect(conflict?.count, 1);
    });

    test('rezervacija koja počinje u radnom vremenu, a završava posle zatvaranja, je sukob', () {
      final conflict = check(week(opens: 8, closes: 16), [reservation(1, start: friday(15), hours: 2)]);

      expect(conflict?.count, 1);
    });

    test('dan koji postaje neradni je sukob za rezervaciju tog dana', () {
      final schedules = [
        for (final weekday in WeekDay.values)
          day(weekday, open: weekday != WeekDay.friday),
      ];

      expect(check(schedules, [reservation(1, start: friday(15))])?.count, 1);
    });

    test('broji sve rezervacije van radnog vremena, a prva je najranija', () {
      final conflict = check(week(opens: 8, closes: 14), [
        reservation(3, start: DateTime(2026, 11, 22, 18)),
        reservation(1, start: friday(15)),
        reservation(2, start: friday(10)),
      ]);

      expect(conflict?.count, 2);
      expect(conflict?.firstStart, friday(15));
    });

    test('otkazana, završena i prošla rezervacija ne smetaju', () {
      final conflict = check(week(opens: 8, closes: 14), [
        reservation(1, start: friday(15), status: ReservationStatus.cancelled),
        reservation(2, start: friday(16), status: ReservationStatus.completed),
        reservation(3, start: DateTime(2026, 11, 10, 15)),
      ]);

      expect(conflict, isNull);
    });

    test('rezervacija na čekanju kojoj je istekao rok se već vidi kao otkazana', () {
      // Rok za potvrdu je 5 sati pre početka; sat je posle roka.
      final late = DateTime(2026, 11, 20, 13);
      final result = validateScheduleAgainstReservations(
        fieldId: fieldId,
        schedules: week(opens: 8, closes: 14),
        reservations: [reservation(1, start: friday(15), status: ReservationStatus.pending)],
        now: late,
      );

      expect(result, isNull);
    });

    test('rezervacija drugog terena ne smeta', () {
      expect(
        check(week(opens: 8, closes: 14), [reservation(1, field: const FieldId(9), start: friday(15))]),
        isNull,
      );
    });

    test('bez rezervacija svako radno vreme prolazi', () {
      expect(check(week(opens: 8, closes: 9), const []), isNull);
    });
  });

  group('kalendar ne sakriva rezervaciju van radnog vremena', () {
    FieldCalendarDay calendar(List<FieldSchedule> schedules, List<Reservation> reservations) =>
        buildFieldCalendarDay(
          fieldId: fieldId,
          date: DateTime(2026, 11, 20),
          schedules: schedules,
          reservations: reservations,
          now: now,
        );

    test('rezervacija u 15 posle skraćenja radnog vremena do 14 ostaje u kalendaru', () {
      final result = calendar(week(opens: 8, closes: 14), [reservation(1, start: friday(15))]);

      final outside = result.entries.whereType<CalendarReservation>().single;
      expect(outside.outsideWorkingHours, isTrue);
      expect(outside.startTime, friday(15));
      // Slobodni termini idu do zatvaranja, pa rezervacija dolazi posle njih.
      expect(result.entries.first, isA<CalendarFreeSlot>());
      expect(result.entries.last, same(outside));
    });

    test('rezervacije u radnom vremenu nisu označene', () {
      final result = calendar(week(), [reservation(1, start: friday(15))]);

      expect(
        result.entries.whereType<CalendarReservation>().single.outsideWorkingHours,
        isFalse,
      );
    });

    test('neradni dan sa rezervacijom: dan je zatvoren, ali rezervacija se vidi', () {
      final schedules = [
        for (final weekday in WeekDay.values) day(weekday, open: weekday != WeekDay.friday),
      ];

      final result = calendar(schedules, [reservation(1, start: friday(15))]);

      expect(result.isOpen, isFalse);
      expect(result.entries, hasLength(1));
      expect((result.entries.single as CalendarReservation).outsideWorkingHours, isTrue);
    });

    test('neradni dan bez rezervacija nema redova', () {
      final schedules = [
        for (final weekday in WeekDay.values) day(weekday, open: weekday != WeekDay.friday),
      ];

      final result = calendar(schedules, const []);

      expect(result.isOpen, isFalse);
      expect(result.entries, isEmpty);
    });
  });
}
