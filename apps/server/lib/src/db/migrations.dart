import 'dart:io';

import 'database.dart';

/// Jedna migracija: SQL fajl `<verzija>_<naziv>.sql` iz `apps/server/migrations`.
final class Migration {
  /// Vremenska oznaka iz imena fajla (`20261110120000`), određuje redosled.
  final String version;
  final String name;
  final String sql;

  const Migration({required this.version, required this.name, required this.sql});

  static final _fileName = RegExp(r'^(\d{14})_([a-z0-9_]+)\.sql$');

  /// Čita sve migracije iz [directory], sortirane po verziji.
  ///
  /// Fajl sa pogrešnim imenom je greška, a ne tiho preskakanje, da se
  /// migracija ne bi izgubila zbog slovne greške u imenu.
  static Future<List<Migration>> readDirectory(Directory directory) async {
    if (!await directory.exists()) {
      throw StateError('Folder sa migracijama ne postoji: ${directory.path}');
    }

    final migrations = <Migration>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final fileName = entity.uri.pathSegments.last;
      if (!fileName.endsWith('.sql')) continue;

      final match = _fileName.firstMatch(fileName);
      if (match == null) {
        throw StateError(
          'Neispravno ime migracije "$fileName"; očekuje se '
          'GGGGMMDDHHMMSS_naziv.sql (npr. 20261110120000_initial_schema.sql).',
        );
      }
      migrations.add(Migration(
        version: match.group(1)!,
        name: match.group(2)!,
        sql: await entity.readAsString(),
      ));
    }

    migrations.sort((a, b) => a.version.compareTo(b.version));
    for (var i = 1; i < migrations.length; i++) {
      if (migrations[i].version == migrations[i - 1].version) {
        throw StateError('Dve migracije imaju istu verziju ${migrations[i].version}.');
      }
    }
    return migrations;
  }

  /// Deli SQL na naredbe po `;` na kraju reda, bez komentara `--`.
  ///
  /// `mysql1` izvršava jednu naredbu po pozivu. Naše migracije ne sadrže
  /// `;` unutar teksta, pa je ovo dovoljno (i proverava se testom).
  List<String> get statements {
    final withoutComments = sql
        .split('\n')
        .map((line) {
          final comment = line.indexOf('--');
          return comment >= 0 ? line.substring(0, comment) : line;
        })
        .join('\n');

    return withoutComments
        .split(RegExp(r';\s*(\n|$)'))
        .map((statement) => statement.trim())
        .where((statement) => statement.isNotEmpty)
        .toList(growable: false);
  }
}

/// Primenjuje migracije koje još nisu primenjene.
///
/// Primenjene se pamte u tabeli `schema_migrations`, pa drugo pokretanje
/// ne radi ništa. Zaključavanje `GET_LOCK` sprečava da dva servera koji se
/// podižu istovremeno primene istu migraciju dvaput.
///
/// MySQL ne može da vrati `CREATE TABLE` unutar transakcije, pa se svaka
/// migracija upisuje kao primenjena tek kada sve njene naredbe prođu. Ako
/// neka padne, server se ne podiže i greška kaže koja migracija i naredba.
final class MigrationRunner {
  final Database database;
  final void Function(String message) log;

  MigrationRunner(this.database, {void Function(String message)? log})
      : log = log ?? ((_) {});

  static const _lockName = 'terenzo_migrations';

  /// Vraća verzije koje su primenjene u ovom pokretanju.
  Future<List<String>> migrate(List<Migration> migrations) {
    // GET_LOCK važi za konekciju, pa sve ide kroz jednu.
    return database.withConnection((db) async {
      final lock = await db.query('SELECT GET_LOCK(?, 60) AS acquired', [_lockName]);
      if (lock.first['acquired'] != 1) {
        throw StateError('Druga instanca servera predugo primenjuje migracije.');
      }

      try {
        await db.query('''
          CREATE TABLE IF NOT EXISTS schema_migrations (
            version    VARCHAR(14)  NOT NULL PRIMARY KEY,
            name       VARCHAR(200) NOT NULL,
            applied_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
          )''');

        final applied = {
          for (final row in await db.query('SELECT version FROM schema_migrations'))
            row['version'] as String,
        };

        final newlyApplied = <String>[];
        for (final migration in migrations) {
          if (applied.contains(migration.version)) continue;

          log('Migracija ${migration.version}_${migration.name}…');
          final statements = migration.statements;
          for (var i = 0; i < statements.length; i++) {
            try {
              await db.query(statements[i]);
            } on Object catch (error) {
              throw MigrationException(migration, i + 1, statements[i], error);
            }
          }
          await db.query(
            'INSERT INTO schema_migrations (version, name) VALUES (?, ?)',
            [migration.version, migration.name],
          );
          newlyApplied.add(migration.version);
        }

        if (newlyApplied.isEmpty) {
          log('Šema je ažurna (${migrations.length} migracija).');
        }
        return newlyApplied;
      } finally {
        await db.query('SELECT RELEASE_LOCK(?)', [_lockName]);
      }
    });
  }
}

/// Naredba iz migracije nije uspela.
final class MigrationException implements Exception {
  final Migration migration;
  final int statementNumber;
  final String statement;
  final Object cause;

  const MigrationException(this.migration, this.statementNumber, this.statement, this.cause);

  @override
  String toString() {
    final preview = statement.length > 200 ? '${statement.substring(0, 200)}…' : statement;
    return 'Migracija ${migration.version}_${migration.name}, naredba $statementNumber nije uspela: '
        '$cause\n$preview';
  }
}
