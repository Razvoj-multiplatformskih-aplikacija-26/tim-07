import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';

import 'auth_event.dart';
import 'auth_state.dart';

/// Prijava, vraćanje prijave, odjava i istek prijave, isto za mobilnu aplikaciju
/// i backoffice. Ne zna da li je iza `AuthRepository` server ili memorija.
///
/// [app] određuje ko sme da uđe: `canSignIn(uloga, app)` iz domena (T45). Nalog
/// koji nije za ovu aplikaciju se odmah odjavljuje uz poruku zašto.
final class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;
  final ClientApp app;
  late final StreamSubscription<void> _expirations;

  AuthBloc({required this.repository, required this.app})
    : super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);

    _expirations = repository.expirations.listen(
      (_) => add(const AuthSessionExpired()),
    );
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    // „Pokušaj ponovo“ vraća ekran u učitavanje; na samom početku je već tu.
    if (state is! AuthUnknown) emit(const AuthUnknown());

    try {
      final session = await repository.restore();
      if (session == null) {
        emit(const AuthUnauthenticated());
        return;
      }
      await _admit(session, emit);
    } catch (error) {
      // Nema servera: prijava ostaje sačuvana, korisnik može da pokuša ponovo.
      emit(
        AuthUnauthenticated(
          reason: SignOutReason.unavailable,
          message: describeError(error),
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Dvostruki klik ne šalje dva zahteva.
    if (state is AuthSigningIn) return;

    final email = event.email.trim();
    if (email.isEmpty || event.password.isEmpty) {
      emit(const AuthFailed(credentialsRequiredMessage));
      return;
    }

    emit(const AuthSigningIn());

    final UserSession session;
    try {
      session = await repository.logIn(email: email, password: event.password);
    } catch (error) {
      emit(AuthFailed(describeError(error)));
      return;
    }

    await _admit(session, emit);
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _logOutQuietly();
    emit(const AuthUnauthenticated(reason: SignOutReason.loggedOut));
  }

  void _onSessionExpired(AuthSessionExpired event, Emitter<AuthState> emit) {
    // Istek se računa samo prijavljenom korisniku.
    if (state is! AuthAuthenticated) return;

    emit(
      const AuthUnauthenticated(
        reason: SignOutReason.expired,
        message: sessionExpiredMessage,
      ),
    );
  }

  Future<void> _admit(UserSession session, Emitter<AuthState> emit) async {
    if (canSignIn(session.user.role, app)) {
      emit(AuthAuthenticated(user: session.user, expiresAt: session.expiresAt));
      return;
    }

    await _logOutQuietly();
    emit(
      AuthUnauthenticated(
        reason: SignOutReason.roleNotAllowed,
        message: signInNotAllowedMessage(app),
      ),
    );
  }

  Future<void> _logOutQuietly() async {
    try {
      await repository.logOut();
    } catch (error, stackTrace) {
      // Odjava ne sme da ostavi korisnika prijavljenog zbog greške skladišta.
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _expirations.cancel();
    return super.close();
  }
}
