import 'dart:io';
import 'dart:math';

import 'package:mysql1/mysql1.dart';
import 'package:server/server.dart';

/// Privremena baza za jedan test fajl, na MySQL-u iz Docker Compose-a.
///
/// Pravi bazu `terenzo_test_<nasumično>` kao root (podaci iz `.env` u korenu)
/// i briše je u [dispose]. Ako MySQL ne radi, [open] vraća `null`, a test se
/// preskače porukom iz [skipReason].
final class TestDatabase {
  final Database database;
  final String name;
  final ConnectionSettings _admin;

  TestDatabase._(this.database, this.name, this._admin);

  static String? skipReason;

  static Future<TestDatabase?> open() async {
    final env = _loadEnv();
    final host = env['DB_TEST_HOST'] ?? '127.0.0.1';
    final port = int.parse(env['DB_PORT'] ?? '3306');
    final admin = ConnectionSettings(
      host: host,
      port: port,
      user: 'root',
      password: env['DB_ROOT_PASSWORD'],
      timeout: const Duration(seconds: 3),
    );

    final name = 'terenzo_test_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    try {
      final connection = await MySqlConnection.connect(admin);
      await connection.query('CREATE DATABASE `$name` CHARACTER SET utf8mb4');
      await connection.close();
    } on Object catch (error) {
      skipReason = 'MySQL nije dostupan na $host:$port (pokreni "docker compose up -d db"): $error';
      return null;
    }

    final database = await Database.connect(
      host: host,
      port: port,
      user: 'root',
      password: env['DB_ROOT_PASSWORD'] ?? '',
      database: name,
      attempts: 1,
    );
    return TestDatabase._(database, name, admin);
  }

  /// Primenjuje migracije iz `apps/server/migrations`.
  Future<void> migrate() async {
    final migrations = await Migration.readDirectory(Directory('migrations'));
    await MigrationRunner(database).migrate(migrations);
  }

  Future<void> dispose() async {
    await database.close();
    final connection = await MySqlConnection.connect(_admin);
    await connection.query('DROP DATABASE IF EXISTS `$name`');
    await connection.close();
  }

  static Map<String, String> _loadEnv() {
    for (final path in ['.env', '../.env', '../../.env']) {
      final file = File(path);
      if (file.existsSync()) {
        return {...parseDotEnv(file.readAsStringSync()), ...Platform.environment};
      }
    }
    return Platform.environment;
  }
}
