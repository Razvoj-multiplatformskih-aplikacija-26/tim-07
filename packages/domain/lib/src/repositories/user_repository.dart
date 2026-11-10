import '../enums.dart';
import '../ids.dart';
import '../models/app_user.dart';

/// Ugovor za čitanje korisnika.
///
/// Lozinke nisu deo domena: heš čuva samo server, van ovog porta.
abstract interface class UserRepository {
  Future<AppUser?> getUserById(UserId id);

  /// Pretraga po e-pošti, bez razlike velikih i malih slova.
  Future<AppUser?> getUserByEmail(String email);

  /// Svi korisnici, ili samo oni sa ulogom [role].
  Future<List<AppUser>> getUsers({UserRole? role});
}
