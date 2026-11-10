import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:mysql1/mysql1.dart';

/// Nešto nad čim se izvršava SQL: ceo pool ili jedna otvorena transakcija.
///
/// Repozitorijumi primaju [SqlExecutor], pa isti kod radi i van i unutar
/// transakcije (npr. provera preklapanja i upis u istoj transakciji).
abstract interface class SqlExecutor {
  Future<Result> query(String sql, [List<Object?>? values]);
}

/// Pool MySQL konekcija.
///
/// `mysql1` daje jednu konekciju koja izvršava upit po upit. Bez poola bi
/// svi zahtevi čekali jedan drugog, a dve transakcije ne bi mogle da idu
/// paralelno — pa ni zaključavanje iz T39 ne bi imalo šta da zaključa.
final class Database implements SqlExecutor {
  final ConnectionSettings _settings;
  final int _maxConnections;

  final _idle = <MySqlConnection>[];
  final _waiters = Queue<Completer<MySqlConnection>>();
  var _open = 0;
  var _closed = false;

  Database._(this._settings, this._maxConnections);

  /// Povezuje se na bazu i čeka je ako još nije spremna.
  ///
  /// Baza u Docker-u se podiže sporije od servera, pa server pokušava
  /// [attempts] puta sa pauzom [delay] umesto da odmah padne.
  static Future<Database> connect({
    required String host,
    required int port,
    required String user,
    required String password,
    required String database,
    int maxConnections = 8,
    int attempts = 30,
    Duration delay = const Duration(seconds: 2),
    void Function(String message)? log,
  }) async {
    final settings = ConnectionSettings(
      host: host,
      port: port,
      user: user,
      password: password,
      db: database,
      timeout: const Duration(seconds: 10),
    );
    final db = Database._(settings, maxConnections);

    for (var attempt = 1; ; attempt++) {
      try {
        final connection = await db._openConnection();
        db._idle.add(connection);
        return db;
      } on Object catch (error) {
        if (attempt >= attempts) rethrow;
        log?.call(
          'Baza još nije spremna ($host:$port, pokušaj $attempt/$attempts): '
          '${_shortError(error)}',
        );
        await Future<void>.delayed(delay);
      }
    }
  }

  Future<MySqlConnection> _openConnection() async {
    final connection = await MySqlConnection.connect(_settings);
    _open++;
    // Vreme u bazi je uvek UTC (odluka 5), nezavisno od zone kontejnera.
    await connection.query("SET time_zone = '+00:00'");
    return connection;
  }

  Future<MySqlConnection> _acquire() async {
    if (_closed) throw StateError('Database je zatvoren.');
    if (_idle.isNotEmpty) return _idle.removeLast();
    if (_open < _maxConnections) return _openConnection();

    final waiter = Completer<MySqlConnection>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release(MySqlConnection connection, {bool broken = false}) {
    if (broken || _closed) {
      _open--;
      unawaited(connection.close().catchError((_) {}));
      if (_waiters.isNotEmpty && !_closed) {
        final waiter = _waiters.removeFirst();
        _openConnection().then(waiter.complete, onError: waiter.completeError);
      }
      return;
    }
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(connection);
    } else {
      _idle.add(connection);
    }
  }

  @override
  Future<Result> query(String sql, [List<Object?>? values]) async {
    final connection = await _acquire();
    try {
      final result = await connection.query(sql, values);
      _release(connection);
      return result;
    } on MySqlException {
      // Greška iz SQL-a: konekcija je ispravna.
      _release(connection);
      rethrow;
    } catch (_) {
      _release(connection, broken: true);
      rethrow;
    }
  }

  /// Izvršava [action] u jednoj transakciji na jednoj konekciji.
  ///
  /// Ako [action] baci izuzetak, sve izmene se poništavaju (`ROLLBACK`) i
  /// izuzetak ide dalje, pa ga HTTP sloj pretvara u kod greške.
  Future<T> transaction<T>(Future<T> Function(SqlExecutor tx) action) {
    return withConnection((connection) async {
      await connection.query('START TRANSACTION');
      try {
        final result = await action(connection);
        await connection.query('COMMIT');
        return result;
      } catch (_) {
        await connection.query('ROLLBACK');
        rethrow;
      }
    });
  }

  /// Izvršava [action] nad jednom konekcijom, bez transakcije.
  ///
  /// Treba kad nešto važi za konekciju, npr. `GET_LOCK` pri migracijama.
  Future<T> withConnection<T>(Future<T> Function(SqlExecutor connection) action) async {
    final connection = await _acquire();
    var broken = false;
    try {
      return await action(_ConnectionExecutor(connection));
    } on SocketException {
      broken = true;
      rethrow;
    } finally {
      _release(connection, broken: broken);
    }
  }

  /// Da li baza odgovara (za `/health`).
  Future<bool> ping() async {
    try {
      await query('SELECT 1');
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> close() async {
    _closed = true;
    for (final waiter in _waiters) {
      waiter.completeError(StateError('Database je zatvoren.'));
    }
    _waiters.clear();
    for (final connection in _idle) {
      await connection.close();
    }
    _idle.clear();
  }

  static String _shortError(Object error) {
    final text = error.toString();
    return text.length > 120 ? '${text.substring(0, 120)}…' : text;
  }
}

final class _ConnectionExecutor implements SqlExecutor {
  final MySqlConnection _connection;

  _ConnectionExecutor(this._connection);

  @override
  Future<Result> query(String sql, [List<Object?>? values]) =>
      _connection.query(sql, values);
}
