import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

void main() {
  late RelicServer server;
  late Uri base;
  var databaseUp = true;

  setUpAll(() async {
    final handler = buildHandler(
      modules: [HealthRoutes(isDatabaseReady: () async => databaseUp)],
      corsAllowedOrigins: const ['http://localhost:*'],
      logRequestsToStdout: false,
    );
    server = await startServer(handler, host: '127.0.0.1', port: 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDownAll(() => server.close());

  test('GET /health vraća 200 kad baza radi', () async {
    databaseUp = true;
    final response = await http.get(base.resolve('/health'));

    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok', 'database': 'up'});
  });

  test('GET /health vraća 503 dok baza ne odgovara', () async {
    databaseUp = false;
    final response = await http.get(base.resolve('/health'));

    expect(response.statusCode, 503);
    databaseUp = true;
  });

  test('nepoznata adresa vraća JSON grešku not_found', () async {
    final response = await http.get(base.resolve('/nema'));

    expect(response.statusCode, 404);
    expect(jsonDecode(response.body), {
      'error': {'code': 'not_found', 'details': <String, Object?>{}},
    });
  });

  group('CORS', () {
    test('preflight sa dozvoljenog porekla dobija zaglavlja', () async {
      final request = http.Request('OPTIONS', base.resolve('/reservations'))
        ..headers['Origin'] = 'http://localhost:5173'
        ..headers['Access-Control-Request-Method'] = 'POST';
      final response = await http.Response.fromStream(await request.send());

      expect(response.statusCode, 204);
      expect(response.headers['access-control-allow-origin'],
          'http://localhost:5173');
      expect(response.headers['access-control-allow-headers'],
          contains('Authorization'));
    });

    test('preflight sa nepoznatog porekla se odbija', () async {
      final request = http.Request('OPTIONS', base.resolve('/reservations'))
        ..headers['Origin'] = 'https://zlonamerni.example';
      final response = await http.Response.fromStream(await request.send());

      expect(response.statusCode, 403);
      expect(response.headers['access-control-allow-origin'], isNull);
    });

    test('običan zahtev sa dozvoljenog porekla nosi Allow-Origin', () async {
      final response = await http.get(
        base.resolve('/health'),
        headers: {'Origin': 'http://localhost:8081'},
      );

      expect(response.headers['access-control-allow-origin'],
          'http://localhost:8081');
    });
  });
}
