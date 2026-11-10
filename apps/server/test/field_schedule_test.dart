@Tags(['db'])
library;

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;
  late MySqlFieldScheduleRepository schedules;
  late MySqlReservationRepository reservations;

  setUp(() async {
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    await testDb!.migrate();
    await insertFixtures(testDb!.database);
    schedules = MySqlFieldScheduleRepository(testDb!.database);
    reservations = MySqlReservationRepository(testDb!.database, clock: () => DateTime(2030, 6, 3, 8));
  });

  tearDown(() async => testDb?.dispose());

  FieldSchedule day(WeekDay dayOfWeek, int opens, int closes, {bool isOpen = true}) => FieldSchedule(
        fieldId: const FieldId(1),
        dayOfWeek: dayOfWeek,
        opensAt: TimeOfDay(hour: opens, minute: 0),
        closesAt: TimeOfDay(hour: closes, minute: 0),
        isOpen: isOpen,
      );

  Future<Reservation> reserve(DateTime start, DateTime end) => reservations.createReservation(
        fieldId: const FieldId(1),
        userId: const UserId(1),
        startTime: start,
        endTime: end,
      );

  Matcher outsideWorkingHours() => throwsA(
        isA<ReservationRuleViolation>().having((e) => e.error, 'error', isA<OutsideWorkingHours>()),
      );

  test('rezervacija van novog radnog vremena se odbija, unutar njega prolazi', () async {
    if (testDb == null) return;
    await schedules.replaceSchedules(const FieldId(1), [day(WeekDay.monday, 10, 16)]);

    await expectLater(reserve(DateTime(2030, 6, 3, 16), DateTime(2030, 6, 3, 17)), outsideWorkingHours());
    await expectLater(reserve(DateTime(2030, 6, 3, 9), DateTime(2030, 6, 3, 11)), outsideWorkingHours());
    expect((await reserve(DateTime(2030, 6, 3, 14), DateTime(2030, 6, 3, 16))).status, ReservationStatus.pending);
  });

  test('neradni dan i dan bez rasporeda se odbijaju', () async {
    if (testDb == null) return;
    await schedules.replaceSchedules(const FieldId(1), [day(WeekDay.monday, 8, 22, isOpen: false)]);

    await expectLater(reserve(DateTime(2030, 6, 3, 12), DateTime(2030, 6, 3, 13)), outsideWorkingHours());
    await expectLater(reserve(DateTime(2030, 6, 4, 12), DateTime(2030, 6, 4, 13)), outsideWorkingHours());
  });

  test('neispravan raspored se odbija i stari raspored ostaje', () async {
    if (testDb == null) return;
    final before = await schedules.getSchedules(const FieldId(1));

    await expectLater(
      schedules.replaceSchedules(const FieldId(1), [day(WeekDay.monday, 9, 17), day(WeekDay.tuesday, 20, 8)]),
      throwsA(isA<ScheduleRuleViolation>()
          .having((e) => e.error, 'error', isA<OpeningAfterClosing>())
          .having((e) => e.error.day, 'day', WeekDay.tuesday)),
    );

    final after = await schedules.getSchedules(const FieldId(1));
    expect(after, hasLength(before.length));
    expect(after.first.opensAt.totalMinutes, before.first.opensAt.totalMinutes);
  });

  test('raspored za nepostojeći teren', () async {
    if (testDb == null) return;

    await expectLater(
      schedules.replaceSchedules(const FieldId(99), const []),
      throwsA(isA<EntityNotFound>()),
    );
  });

  test('istovremena izmena rasporeda i rezervacija: rezervacija važi po jednom od dva rasporeda', () async {
    if (testDb == null) return;
    final start = DateTime(2030, 6, 3, 18);
    final end = DateTime(2030, 6, 3, 19);

    final results = await Future.wait([
      schedules
          .replaceSchedules(const FieldId(1), [day(WeekDay.monday, 8, 12)])
          .then<Object>((_) => 'raspored', onError: (Object e) => e),
      reserve(start, end).then<Object>((r) => r, onError: (Object e) => e),
    ]);

    expect(results.first, 'raspored');
    final reservation = results.last;
    if (reservation is Reservation) {
      expect(reservation.startTime, start.toUtc());
    } else {
      expect(reservation, isA<ReservationRuleViolation>());
    }
    expect((await schedules.getSchedules(const FieldId(1))).single.closesAt.hour, 12);
  });
}
