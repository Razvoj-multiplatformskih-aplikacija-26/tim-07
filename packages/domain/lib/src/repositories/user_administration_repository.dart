import '../enums.dart';
import '../ids.dart';
import '../models/app_user.dart';

/// Ugovor za stranicu „Korisnici“ u backoffice-u: spisak svih naloga i
/// deaktivacija. Samo administrator sme da ga koristi (`canManageUsers`).
abstract interface class UserAdministrationRepository {
  Future<List<AppUser>> getUsers({UserRole? role});

  /// Deaktivira nalog (`active: false`) ili ga ponovo aktivira. Vraća nalog
  /// posle izmene. Baca `EntityNotFound` za nepoznat nalog.
  Future<AppUser> setUserActive(UserId id, {required bool active});
}
