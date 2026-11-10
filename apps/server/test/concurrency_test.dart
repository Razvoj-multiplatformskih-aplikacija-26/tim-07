@Tags(['db'])
library;

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;
  late MySqlReservationRepository reservations;
  const parallelClients = 12;

  final now = DateTime(2030, 6, 3, 10);
  DateTime at(int day, int hour, [int minute = 0]) => DateTime(2030, 6, day, hour, minute);

  setUp(() async {
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    final db = testDb!.database;
    await testDb!.migrate();
    await insertFixtures(db);
    for (var id = 100; id < 100 + parallelClients; id++) {
      await db.query(
        "INSERT INTO users (id, first_name, last_name, email, phone_number, date_of_birth, role, password_hash) "
        "VALUES (?, 'Klijent', '$id', 'klijent$id@example.com', '060', '2000-01-01', 'user', 'x')",
        [id],
      );
    }
    reservations = MySqlReservationRepository(db, clock: () => now);
  });

  tearDown(() async => testDb?.dispose());

  Future<List<Object>> runInParallel(List<Future<Reservation> Function()> calls) {
    return Future.wait([
      for (final call in calls)
        call().then<Object>((reservation) => reservation, onError: (Object error) => error),
    ]);
  }

  Future<int> activeReservationsOnField(int fieldId) async {
    final rows = await testDb!.database.query(
      "SELECT COUNT(*) FROM reservations WHERE field_id = ? AND status IN ('pending', 'confirmed')",
      [fieldId],
    );
    return rows.first[0] as int;
  }

  test('$parallelClients korisnika istovremeno traži isti termin: upisuje se tačno jedna', () async {
    if (testDb == null) return;

    final results = await runInParallel([
      for (var id = 100; id < 100 + parallelClients; id++)
        () => reservations.createReservation(
              fieldId: FieldId(1),
              userId: UserId(id),
              startTime: at(4, 18),
              endTime: at(4, 19),
            ),
    ]);

    expect(results.whereType<Reservation>(), hasLength(1));
    final refused = results.whereType<ReservationRuleViolation>().toList();
    expect(refused, hasLength(parallelClients - 1));
    expect(refused.map((e) => e.error), everyElement(isA<SlotAlreadyTaken>()));
    expect(results.where((r) => r is! Reservation && r is! ReservationRuleViolation), isEmpty);
    expect(await activeReservationsOnField(1), 1);
  });

  test('istovremeni termini koji se samo delimično preklapaju: prolazi jedan', () async {
    if (testDb == null) return;

    final results = await runInParallel([
      for (var i = 0; i < parallelClients; i++)
        () => reservations.createReservation(
              fieldId: FieldId(1),
              userId: UserId(100 + i),
              startTime: at(4, 17).add(Duration(minutes: 10 * i)),
              endTime: at(4, 19).add(Duration(minutes: 10 * i)),
            ),
    ]);

    expect(results.whereType<Reservation>(), hasLength(1));
    expect(await activeReservationsOnField(1), 1);
  });

  test('isti termin na različitim terenima ne smeta jedan drugom', () async {
    if (testDb == null) return;

    final results = await runInParallel([
      () => reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(100), startTime: at(4, 18), endTime: at(4, 19)),
      () => reservations.createReservation(
          fieldId: FieldId(2), userId: UserId(101), startTime: at(4, 18), endTime: at(4, 19)),
    ]);

    expect(results.whereType<Reservation>(), hasLength(2));
  });

  test('isti korisnik istovremeno na dva terena u isto vreme: prolazi jedna', () async {
    if (testDb == null) return;

    final results = await runInParallel([
      () => reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(100), startTime: at(4, 18), endTime: at(4, 19)),
      () => reservations.createReservation(
          fieldId: FieldId(2), userId: UserId(100), startTime: at(4, 18), endTime: at(4, 19)),
    ]);

    expect(results.whereType<Reservation>(), hasLength(1));
    expect(
      results.whereType<ReservationRuleViolation>().single.error,
      isA<SlotAlreadyTaken>(),
    );
  });

  test('otkazivanje i potvrda iste rezervacije u isto vreme: ishod je dosledan', () async {
    if (testDb == null) return;
    final created = await reservations.createReservation(
      fieldId: FieldId(1), userId: UserId(100), startTime: at(5, 18), endTime: at(5, 19),
    );

    final results = await runInParallel([
      () => reservations.cancelReservation(created.id),
      () => reservations.updateReservationStatus(
          reservationId: created.id, status: ReservationStatus.confirmed),
    ]);

    final stored = await reservations.getReservationById(created.id);
    final succeeded = results.whereType<Reservation>().toList();
    expect(succeeded, isNotEmpty);
    if (succeeded.length == 1) {
      expect(stored!.status, succeeded.single.status);
      expect(
        results.whereType<ReservationRuleViolation>().single.error,
        isA<InvalidReservationStatus>(),
      );
    } else {
      expect(stored!.status, ReservationStatus.cancelled);
    }
  });
}
