import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Zašto korisnik nije prijavljen.
enum SignOutReason {
  /// Korisnik se sam odjavio.
  loggedOut,

  /// Prijava je istekla; aplikacija to kaže i traži novu prijavu.
  expired,

  /// Server nije dostupan pri vraćanju prijave. Sačuvana prijava nije obrisana.
  unavailable,

  /// Nalog nije za ovu aplikaciju (korisnik u backoffice-u, vlasnik u mobilnoj).
  roleNotAllowed,
}

sealed class AuthState extends Equatable {
  const AuthState();

  /// Prijavljen korisnik, ili `null`. Ekrani ga čitaju odavde, ne iz demo podataka.
  AppUser? get user => null;

  /// Poruka za korisnika, ako je ima.
  String? get message => null;

  @override
  List<Object?> get props => [];
}

/// Pokretanje: još se ne zna da li postoji sačuvana prijava.
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Prijava je u toku.
final class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

final class AuthAuthenticated extends AuthState {
  @override
  final AppUser user;
  final DateTime expiresAt;

  const AuthAuthenticated({required this.user, required this.expiresAt});

  @override
  List<Object?> get props => [user.id, user.role, user.email, expiresAt];
}

/// Niko nije prijavljen. [reason] je `null` kada prijave nikad nije ni bilo.
final class AuthUnauthenticated extends AuthState {
  final SignOutReason? reason;

  @override
  final String? message;

  const AuthUnauthenticated({this.reason, this.message});

  @override
  List<Object?> get props => [reason, message];
}

/// Prijava nije uspela (pogrešna lozinka, nema mreže, prazna polja).
final class AuthFailed extends AuthState {
  @override
  final String message;

  const AuthFailed(this.message);

  @override
  List<Object?> get props => [message];
}
