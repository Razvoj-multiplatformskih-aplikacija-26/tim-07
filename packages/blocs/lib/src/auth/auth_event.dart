import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Pri pokretanju aplikacije (i osvežavanju stranice): vrati sačuvanu prijavu.
/// Šalje se i za „Pokušaj ponovo“ kada servera nije bilo.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Korisnik je uneo e-mail i lozinku.
final class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  // Lozinka nije u props: ne završava u logu ni u poređenju događaja.
  @override
  List<Object?> get props => [email];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Server je rekao da prijava više ne važi (šalje je sam Bloc iz `expirations`).
final class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}
