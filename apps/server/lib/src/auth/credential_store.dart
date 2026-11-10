import 'package:domain/domain.dart';

import '../db/database.dart';
import '../db/rows.dart';

typedef Credentials = ({AppUser user, String passwordHash});

abstract interface class CredentialStore {
  Future<Credentials?> findByEmail(String email);
}

final class MySqlCredentialStore implements CredentialStore {
  final SqlExecutor _db;

  MySqlCredentialStore(this._db);

  @override
  Future<Credentials?> findByEmail(String email) async {
    final rows = await _db.query(
      'SELECT ${Rows.userColumns}, u.password_hash FROM users u WHERE u.email = ?',
      [email.trim()],
    );
    if (rows.isEmpty) return null;
    return (user: Rows.user(rows.first), passwordHash: rows.first['password_hash'] as String);
  }
}
