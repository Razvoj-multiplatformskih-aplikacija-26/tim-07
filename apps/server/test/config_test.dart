import 'package:server/server.dart';
import 'package:test/test.dart';

const _valid = {
  'SERVER_PORT': '8080',
  'DB_HOST': 'localhost',
  'DB_PORT': '3306',
  'DB_NAME': 'terenzo',
  'DB_USER': 'terenzo',
  'DB_PASSWORD': 'secret',
  'JWT_SECRET': '0123456789abcdef0123456789abcdef',
  'JWT_TTL_MINUTES': '60',
  'CORS_ALLOWED_ORIGINS': 'http://localhost:*, https://admin.example.com',
};

void main() {
  group('ServerConfig', () {
    test('čita sve vrednosti iz okruženja', () {
      final config = ServerConfig.fromEnvironment(_valid);

      expect(config.port, 8080);
      expect(config.host, '0.0.0.0');
      expect(config.dbName, 'terenzo');
      expect(config.tokenTtl, const Duration(minutes: 60));
      expect(config.corsAllowedOrigins,
          ['http://localhost:*', 'https://admin.example.com']);
      expect(config.seedDemoData, isFalse);
      expect(config.notificationApiKey, isEmpty);
    });

    test('ključ spoljnog servisa čita se samo iz okruženja servera', () {
      final config = ServerConfig.fromEnvironment({..._valid, 'NOTIFICATION_API_KEY': ' kljuc '});

      expect(config.notificationApiKey, 'kljuc');
    });

    test('prijavljuje sve vrednosti koje nedostaju odjednom', () {
      final env = Map.of(_valid)
        ..remove('JWT_SECRET')
        ..remove('DB_PASSWORD');

      expect(
        () => ServerConfig.fromEnvironment(env),
        throwsA(isA<ConfigException>().having(
          (e) => e.problems,
          'problems',
          containsAll(['JWT_SECRET nije podešen', 'DB_PASSWORD nije podešen']),
        )),
      );
    });

    test('odbija prekratku tajnu i neispravan port', () {
      final env = {..._valid, 'JWT_SECRET': 'kratko', 'SERVER_PORT': 'abc'};

      expect(
        () => ServerConfig.fromEnvironment(env),
        throwsA(isA<ConfigException>()
            .having((e) => e.problems.length, 'broj problema', 2)),
      );
    });
  });

  group('parseDotEnv', () {
    test('preskače komentare i prazne redove, skida navodnike', () {
      final values = parseDotEnv('''
# komentar
SERVER_PORT=8080

DB_PASSWORD="a=b c"
EMPTY=
''');

      expect(values, {'SERVER_PORT': '8080', 'DB_PASSWORD': 'a=b c', 'EMPTY': ''});
    });
  });
}
