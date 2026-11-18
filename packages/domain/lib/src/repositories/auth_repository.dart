import '../models/app_user.dart';

/// Prijavljen korisnik i do kada prijava važi.
final class UserSession {
  final AppUser user;
  final DateTime expiresAt;

  const UserSession({required this.user, required this.expiresAt});
}

/// Ugovor za prijavu. Ne zna da li iza njega stoji server, memorija ili
/// bezbedno skladište platforme; `AuthBloc` radi isto sa svakom implementacijom.
///
/// Greške (pogrešna lozinka, nema mreže) stižu kao izuzeci koje Bloc pretvara
/// u poruku za korisnika.
abstract interface class AuthRepository {
  /// Prijavljuje korisnika. Baca izuzetak kada podaci nisu ispravni.
  Future<UserSession> logIn({required String email, required String password});

  /// Vraća prijavu sačuvanu pre ponovnog pokretanja ili osvežavanja stranice,
  /// ili `null` kada je nema ili je istekla.
  Future<UserSession?> restore();

  /// Briše sačuvanu prijavu.
  Future<void> logOut();

  /// Javlja kada prijava prestane da važi dok aplikacija radi.
  Stream<void> get expirations;
}
