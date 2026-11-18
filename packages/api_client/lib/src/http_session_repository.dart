import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';

import 'api_client.dart';

/// Prijava, vraćanje prijave i odjava.
///
/// Token čuva [SessionStore] iza porta; lozinka se nikad ne čuva. Odjava ne
/// zove server: token se ne čuva na serveru, pa ga klijent samo briše (odluka 11).
final class HttpSessionRepository implements AuthRepository {
  const HttpSessionRepository(this._api);

  final ApiClient _api;

  /// Pogrešna lozinka stiže kao `ServerRejectedException` sa kodom
  /// `invalid_credentials`; poruku pravi `describeError`.
  @override
  Future<UserSession> logIn({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(
      ApiPaths.login,
      body: LoginRequestDto(email: email, password: password).toJson(),
    );
    final session = readBody(json, SessionDto.fromJson);

    final token = session.token;
    if (token == null) {
      // Prijava bez tokena je neispravan odgovor servera.
      throw const ServerRejectedException(ErrorDto(code: ErrorCodes.internal));
    }
    final user = readBody(json, (_) => session.user.toDomain());
    final result = UserSession(user: user, expiresAt: session.expiresAt);
    await _api.session.write(token);
    return result;
  }

  /// Vraća prijavu posle ponovnog pokretanja ili osvežavanja stranice.
  ///
  /// `null` kada nema sačuvane prijave ili je istekla (token se tada briše).
  /// Kada servera nema, baca `ServerUnreachableException` i **ne** briše token:
  /// korisnik ne sme da ostane odjavljen samo zato što je mreža pala.
  @override
  Future<UserSession?> restore() async {
    if (await _api.session.read() == null) return null;

    try {
      final json = await _api.get(ApiPaths.me);
      final session = readBody(json, SessionDto.fromJson);
      final user = readBody(json, (_) => session.user.toDomain());
      return UserSession(user: user, expiresAt: session.expiresAt);
    } on ServerRejectedException catch (error) {
      final code = error.error.code;
      if (code == ErrorCodes.tokenExpired ||
          code == ErrorCodes.invalidToken ||
          code == ErrorCodes.unauthenticated) {
        await _api.session.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logOut() => _api.session.clear();

  /// Javlja kada server kaže da prijava više ne važi.
  @override
  Stream<void> get expirations => _api.expirations;
}
