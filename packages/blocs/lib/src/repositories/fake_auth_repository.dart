import 'dart:async';

import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';

/// Nalog za demo i testove: korisnik i njegova lozinka.
final class FakeAccount {
  final AppUser user;
  final String password;

  const FakeAccount({required this.user, required this.password});
}

/// Prijava u memoriji, bez servera. Zamenljiva sa HTTP implementacijom
/// (`HttpSessionRepository`) bez izmene Bloc-a i ekrana.
///
/// Sačuvana prijava živi koliko i objekat, pa dva Bloc-a nad istim
/// repozitorijumom glume „ponovno pokretanje aplikacije“.
final class FakeAuthRepository implements AuthRepository {
  final Map<String, FakeAccount> _accounts;
  final Duration delay;
  final Duration sessionLength;
  final DateTime Function() _clock;
  final _expirations = StreamController<void>.broadcast();

  UserSession? _session;

  /// Sledeći pozivi bacaju grešku mreže, kao da server ne radi.
  bool simulateUnreachable = false;

  FakeAuthRepository({
    required Iterable<FakeAccount> accounts,
    this.delay = Duration.zero,
    this.sessionLength = const Duration(hours: 8),
    DateTime Function()? clock,
  }) : _accounts = {
         for (final account in accounts)
           account.user.email.toLowerCase(): account,
       },
       _clock = clock ?? DateTime.now;

  /// Prijava koja je sada sačuvana, ili `null`.
  UserSession? get stored => _session;

  /// Server kaže da prijava ne važi više (istekao token).
  void expire() {
    _session = null;
    _expirations.add(null);
  }

  Future<void> _network() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (simulateUnreachable) throw const ServerUnreachableException();
  }

  @override
  Future<UserSession> logIn({
    required String email,
    required String password,
  }) async {
    await _network();

    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const ServerRejectedException(
        ErrorDto(code: ErrorCodes.invalidCredentials),
      );
    }

    return _session = UserSession(
      user: account.user,
      expiresAt: _clock().toUtc().add(sessionLength),
    );
  }

  @override
  Future<UserSession?> restore() async {
    final session = _session;
    if (session == null) return null;

    await _network();

    if (!_clock().toUtc().isBefore(session.expiresAt)) {
      _session = null;
      return null;
    }
    return session;
  }

  @override
  Future<void> logOut() async => _session = null;

  @override
  Stream<void> get expirations => _expirations.stream;
}
