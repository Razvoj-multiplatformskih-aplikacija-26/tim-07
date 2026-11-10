import 'dart:io';

import 'package:mysql1/mysql1.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/test_database.dart';

void main() {
  group('Migration (bez baze)', () {
    test('deli SQL na naredbe i izbacuje komentare', () {
      const migration = Migration(version: '20260101000000', name: 'x', sql: '''
-- komentar; sa tačkom-zarezom
CREATE TABLE a (id INT); -- posle naredbe
CREATE TABLE b (
  id INT
);
''');

      expect(migration.statements, [
        'CREATE TABLE a (id INT)',
        'CREATE TABLE b (\n  id INT\n)',
      ]);
    });

    test('migracije iz repozitorijuma se čitaju sortirane po verziji', () async {
      final migrations = await Migration.readDirectory(Directory('migrations'));

      expect(migrations, isNotEmpty);
      expect(migrations.first.name, 'initial_schema');
      final versions = migrations.map((m) => m.version).toList();
      expect(versions, [...versions]..sort());
    });

    test('fajl sa pogrešnim imenom je greška, ne tiho preskakanje', () async {
      final dir = await Directory.systemTemp.createTemp('migrations');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/schema.sql').writeAsString('SELECT 1;');

      expect(() => Migration.readDirectory(dir), throwsStateError);
    });
  });

  group('MigrationRunner nad MySQL-om', tags: 'db', () {
    TestDatabase? testDb;

    setUp(() async {
      testDb = await TestDatabase.open();
      if (testDb == null) markTestSkipped(TestDatabase.skipReason!);
    });

    tearDown(() async => testDb?.dispose());

    Future<Set<String>> tables(Database db) async => {
          for (final row in await db.query('SHOW TABLES')) row[0] as String,
        };

    test('prazna baza se do kraja podiže samo iz migracija', () async {
      final db = testDb?.database;
      if (db == null) return;

      await testDb!.migrate();

      expect(await tables(db), {
        'schema_migrations',
        'users',
        'sports_fields',
        'field_images',
        'field_schedules',
        'blocked_periods',
        'reservations',
        'reviews',
      });
    });

    test('drugo pokretanje ne radi ništa i ne duplira zapise', () async {
      final db = testDb?.database;
      if (db == null) return;
      final migrations = await Migration.readDirectory(Directory('migrations'));

      final first = await MigrationRunner(db).migrate(migrations);
      final second = await MigrationRunner(db).migrate(migrations);

      expect(first, hasLength(migrations.length));
      expect(second, isEmpty);
      final count = await db.query('SELECT COUNT(*) FROM schema_migrations');
      expect(count.first[0], migrations.length);
    });

    test('dva servera koja se podižu istovremeno primenjuju šemu jednom', () async {
      final db = testDb?.database;
      if (db == null) return;
      final migrations = await Migration.readDirectory(Directory('migrations'));

      final results = await Future.wait([
        MigrationRunner(db).migrate(migrations),
        MigrationRunner(db).migrate(migrations),
      ]);

      expect(results.expand((applied) => applied), hasLength(migrations.length));
    });

    group('ograničenja u bazi', () {
      late Database db;

      setUp(() async {
        if (testDb == null) return;
        db = testDb!.database;
        await testDb!.migrate();
        await db.query('''
          INSERT INTO users (id, first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
          VALUES (1, 'Ana', 'Anić', 'ana@example.com', '060', '2000-01-01', 'user', 'x'),
                 (2, 'Vlada', 'Vlasnik', 'vlada@example.com', '061', '1990-01-01', 'owner', 'x')''');
        await db.query('''
          INSERT INTO sports_fields (id, owner_id, name, description, sport, address, city,
                                     price_per_hour, contact_phone, confirmation_mode)
          VALUES (1, 2, 'Arena', 'Opis', 'football', 'Ulica 1', 'Beograd', 3000, '060', 'manual')''');
      });

      Future<void> insertReservation({
        required String start,
        required String end,
        String status = 'pending',
        int price = 3000,
        int userId = 1,
      }) =>
          db.query(
            'INSERT INTO reservations (field_id, user_id, start_time, end_time, total_price, status) '
            'VALUES (1, ?, ?, ?, ?, ?)',
            [userId, start, end, price, status],
          );

      test('ispravna rezervacija se upisuje', () async {
        if (testDb == null) return;
        await insertReservation(start: '2026-12-01 17:00:00', end: '2026-12-01 18:00:00');

        final rows = await db.query('SELECT status, payment_status FROM reservations');
        expect(rows.single[0], 'pending');
        expect(rows.single[1], 'unpaid');
      });

      test('kraj pre početka odbija baza (CHECK start < end)', () async {
        if (testDb == null) return;
        expect(
          insertReservation(start: '2026-12-01 18:00:00', end: '2026-12-01 17:00:00'),
          throwsA(isA<MySqlException>()),
        );
      });

      test('nepoznato stanje i negativna cena se odbijaju', () async {
        if (testDb == null) return;
        expect(
          insertReservation(start: '2026-12-01 17:00:00', end: '2026-12-01 18:00:00', status: 'arrived'),
          throwsA(isA<MySqlException>()),
        );
        expect(
          insertReservation(start: '2026-12-01 17:00:00', end: '2026-12-01 18:00:00', price: -1),
          throwsA(isA<MySqlException>()),
        );
      });

      test('rezervacija za nepostojećeg korisnika se odbija (strani ključ)', () async {
        if (testDb == null) return;
        expect(
          insertReservation(start: '2026-12-01 17:00:00', end: '2026-12-01 18:00:00', userId: 99),
          throwsA(isA<MySqlException>()),
        );
      });

      test('e-pošta korisnika je jedinstvena', () async {
        if (testDb == null) return;
        expect(
          db.query('''
            INSERT INTO users (first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
            VALUES ('Druga', 'Ana', 'ana@example.com', '062', '2001-01-01', 'user', 'x')'''),
          throwsA(isA<MySqlException>()),
        );
      });

      test('ocena mora biti od 1 do 5', () async {
        if (testDb == null) return;
        await insertReservation(
            start: '2026-11-01 17:00:00', end: '2026-11-01 18:00:00', status: 'completed');
        expect(
          db.query(
            "INSERT INTO reviews (reservation_id, reviewer_id, type, reviewed_field_id, rating) "
            "VALUES (1, 1, 'field', 1, 6)",
          ),
          throwsA(isA<MySqlException>()),
        );
      });
    });
  });
}
