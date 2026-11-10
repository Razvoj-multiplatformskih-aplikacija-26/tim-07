@Tags(['db'])
library;

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;
  final week = StatsPeriod.weekOf(DateTime(2030, 6, 3));
  const dailyMinutes = 15 * 60;

  setUp(() async {
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    await testDb!.migrate();
    final db = testDb!.database;
    await insertFixtures(db);
    await db.query('''
      INSERT INTO users (id, first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
      VALUES (5, 'Druga', 'Vlasnica', 'druga@example.com', '0605', '1980-01-01', 'owner', 'x')''');
    await db.query('''
      INSERT INTO sports_fields (id, owner_id, name, description, sport, address, city,
                                 price_per_hour, contact_phone, confirmation_mode, approval_status)
      VALUES (4, 5, 'Tuđi teren', '', 'football', 'Ulica 4', 'Niš', 2000, '065', 'manual', 'approved')''');

    Future<void> insert(int fieldId, DateTime start, DateTime end, String status, {DateTime? checkedIn}) =>
        db.query(
          'INSERT INTO reservations (field_id, user_id, start_time, end_time, total_price, status, checked_in_at) '
          'VALUES (?, 1, ?, ?, 0, ?, ?)',
          [fieldId, start.toUtc(), end.toUtc(), status, checkedIn?.toUtc()],
        );

    await insert(1, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 20), 'completed');
    await insert(1, DateTime(2030, 6, 4, 18), DateTime(2030, 6, 4, 19), 'confirmed',
        checkedIn: DateTime(2030, 6, 4, 9));
    await insert(1, DateTime(2030, 6, 5, 18), DateTime(2030, 6, 5, 19), 'cancelled');
    await insert(2, DateTime(2030, 6, 6, 10), DateTime(2030, 6, 6, 13), 'confirmed');
    await insert(1, DateTime(2030, 6, 12, 18), DateTime(2030, 6, 12, 19), 'confirmed');
    await insert(4, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 20), 'completed');
  });

  tearDown(() async => testDb?.dispose());

  test('vlasnik vidi zauzetost samo svojih terena, iz podataka u bazi', () async {
    if (testDb == null) return;
    final statistics = MySqlStatisticsRepository(testDb!.database, clock: () => DateTime(2030, 6, 4, 21));

    final report = await statistics.getOccupancy(period: week, ownerId: const UserId(3));

    expect(report.fields.map((f) => f.fieldName), ['Arena', 'Novi', 'Tenis']);
    final arena = report.fields.first;
    expect(arena.availableMinutes, 7 * dailyMinutes);
    expect(arena.bookedMinutes, 180);
    expect(arena.completedCount, 2);
    expect(arena.cancelledCount, 1);
    expect(report.fields.last.bookedMinutes, 180);
    expect(report.completedCount, 2);
  });

  test('administrator (bez vlasnika) vidi sve terene', () async {
    if (testDb == null) return;
    final statistics = MySqlStatisticsRepository(testDb!.database, clock: () => DateTime(2030, 6, 1));

    final report = await statistics.getOccupancy(period: week);

    expect(report.fields, hasLength(4));
    expect(report.fields.map((f) => f.fieldName), contains('Tuđi teren'));
  });

  test('vlasnik bez terena dobija prazan izveštaj', () async {
    if (testDb == null) return;
    final statistics = MySqlStatisticsRepository(testDb!.database);

    final report = await statistics.getOccupancy(period: week, ownerId: const UserId(1));

    expect(report.fields, isEmpty);
    expect(report.occupancyPercent, 0);
  });
}
