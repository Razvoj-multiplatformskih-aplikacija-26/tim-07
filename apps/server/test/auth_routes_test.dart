@Tags(['db'])
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;
  RelicServer? server;
  late Uri base;
  var now = DateTime.utc(2030, 6, 3, 10);

  setUp(() async {
    now = DateTime.utc(2030, 6, 3, 10);
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    final db = testDb!.database;
    await testDb!.migrate();
    await insertFixtures(db);
    await db.query('UPDATE users SET password_hash = ? WHERE id = 1', [await hashPassword('ana-lozinka')]);
    await db.query('UPDATE users SET password_hash = ? WHERE id = 3', [await hashPassword('vlada-lozinka')]);

    final handler = buildHandler(
      modules: [
        AuthRoutes(
          credentials: MySqlCredentialStore(db),
          users: MySqlUserRepository(db),
          tokens: TokenService(
            secret: '0123456789abcdef0123456789abcdef',
            ttl: const Duration(minutes: 30),
            clock: () => now,
          ),
        ),
      ],
      logRequestsToStdout: false,
    );
    server = await startServer(handler, host: '127.0.0.1', port: 0);
    base = Uri.parse('http://127.0.0.1:${server!.port}');
  });

  tearDown(() async {
    await server?.close();
    await testDb?.dispose();
  });

  Future<http.Response> login(String email, String password) => http.post(
        base.resolve('/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

  Future<http.Response> me(String? token) => http.get(
        base.resolve('/auth/me'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

  String code(http.Response response) =>
      ((jsonDecode(response.body) as Map)['error'] as Map)['code'] as String;

  test('prijava vraća token, korisnika i vreme isteka, bez heša lozinke', () async {
    if (testDb == null) return;
    final response = await login('ana@example.com', 'ana-lozinka');

    expect(response.statusCode, 200);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['token'], isA<String>());
    expect(body['expiresAt'], '2030-06-03T10:30:00.000Z');
    expect(body['user'], {
      'id': 1, 'firstName': 'Ana', 'lastName': 'Anić', 'email': 'ana@example.com', 'role': 'user',
    });
    expect(response.body, isNot(contains('argon2')));
  });

  test('pogrešna lozinka i nepostojeći nalog daju istu grešku', () async {
    if (testDb == null) return;
    final wrongPassword = await login('ana@example.com', 'pogresna');
    final noAccount = await login('nema@example.com', 'ana-lozinka');

    expect(wrongPassword.statusCode, 401);
    expect(noAccount.statusCode, 401);
    expect(code(wrongPassword), 'invalid_credentials');
    expect(code(noAccount), 'invalid_credentials');
  });

  test('neispravno telo prijave → 400', () async {
    if (testDb == null) return;
    final response = await http.post(base.resolve('/auth/login'), body: '{"email": 5}');

    expect(response.statusCode, 400);
    expect(code(response), 'bad_request');
  });

  test('/auth/me zna ko poziva samo iz tokena', () async {
    if (testDb == null) return;
    final token = (jsonDecode((await login('vlada@example.com', 'vlada-lozinka')).body) as Map)['token'];

    final response = await me(token as String);
    expect(response.statusCode, 200);
    expect(((jsonDecode(response.body) as Map)['user'] as Map)['role'], 'owner');
  });

  test('bez tokena → 401 unauthenticated', () async {
    if (testDb == null) return;
    final response = await me(null);

    expect(response.statusCode, 401);
    expect(code(response), 'unauthenticated');
    expect(response.headers['www-authenticate'], 'Bearer');
  });

  test('istekao token → 401 token_expired', () async {
    if (testDb == null) return;
    final token = (jsonDecode((await login('ana@example.com', 'ana-lozinka')).body) as Map)['token'] as String;

    now = now.add(const Duration(minutes: 31));
    final response = await me(token);
    expect(response.statusCode, 401);
    expect(code(response), 'token_expired');
  });

  test('izmenjen token → 401 invalid_token', () async {
    if (testDb == null) return;
    final token = (jsonDecode((await login('ana@example.com', 'ana-lozinka')).body) as Map)['token'] as String;
    final tampered = '${token.substring(0, token.length - 2)}xx';

    final response = await me(tampered);
    expect(response.statusCode, 401);
    expect(code(response), 'invalid_token');
  });

  test('u bazi su samo heševi lozinki', () async {
    if (testDb == null) return;
    final rows = await testDb!.database.query('SELECT password_hash FROM users WHERE id IN (1, 3)');

    for (final row in rows) {
      expect(row[0] as String, startsWith(r'$argon2id$'));
      expect(row[0] as String, isNot(contains('lozinka')));
    }
  });
}
