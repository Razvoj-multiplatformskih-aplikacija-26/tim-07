import 'package:contract/contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:relic/relic.dart';

import 'http.dart';
import 'passwords.dart';
import 'terenzo_store.dart';

final class SignedIn {
  const SignedIn({required this.user, required this.expiresAt});

  final AppUser user;
  final DateTime expiresAt;
}

final currentSession = ContextProperty<SignedIn>('session');

AppUser actorOf(Request request) => currentSession.get(request).user;

AppUser? optionalActorOf(Request request) => currentSession[request]?.user;

const _algorithm = JWTAlgorithm.HS256;

final class SessionHandlers {
  SessionHandlers({
    required this.store,
    required String secret,
    required this.ttl,
    DateTime Function()? clock,
  }) : _key = SecretKey(secret),
       _clock = clock ?? DateTime.now,
       _noAccountHash = hashPassword('no such account');

  final TerenzoStore store;
  final Duration ttl;
  final SecretKey _key;
  final DateTime Function() _clock;
  final Future<String> _noAccountHash;

  Handler signedIn(Handler handler) => (Request request) async {
    final token = _tokenOf(request);
    if (token == null) return _unauthorized(ErrorCodes.unauthenticated);
    final verified = await _verify(token);
    if (verified case final String code) return _unauthorized(code);
    currentSession[request] = verified! as SignedIn;
    return handler(request);
  };

  Handler optionallySignedIn(Handler handler) => (Request request) async {
    final token = _tokenOf(request);
    if (token != null) {
      final verified = await _verify(token);
      if (verified case final String code) return _unauthorized(code);
      currentSession[request] = verified! as SignedIn;
    }
    return handler(request);
  };

  Future<Response> logIn(Request request) async {
    final object = await readObject(request);
    final body = parseBody(() => LoginRequestDto.fromJson(object));
    final account = await store.account(body.email);
    final matches = await verifyPassword(body.password, account?.passwordHash ?? await _noAccountHash);
    if (account == null || !matches) return _unauthorized(ErrorCodes.invalidCredentials);

    final now = _clock().toUtc();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (now.add(ttl).millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final token = JWT({
      'role': account.user.role.name,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
    }, subject: '${account.user.id.value}').sign(_key, algorithm: _algorithm, noIssueAt: true);

    return json(200, SessionDto(user: account.user.toDto(), expiresAt: expiresAt, token: token).toJson());
  }

  Future<Response> current(Request request) async {
    final session = currentSession.get(request);
    return json(200, SessionDto(user: session.user.toDto(), expiresAt: session.expiresAt).toJson());
  }

  Future<Response> logOut(Request request) async => Response.noContent();

  Future<Object?> _verify(String token) async {
    final Map<String, dynamic> payload;
    try {
      if (JWT.decode(token).header?['alg'] != _algorithm.name) return ErrorCodes.invalidToken;
      final verified = JWT.verify(token, _key, checkExpiresIn: false, checkNotBefore: false);
      if (verified.payload is! Map<String, dynamic>) return ErrorCodes.invalidToken;
      payload = verified.payload as Map<String, dynamic>;
    } on JWTException {
      return ErrorCodes.invalidToken;
    } on FormatException {
      return ErrorCodes.invalidToken;
    } on ArgumentError {
      return ErrorCodes.invalidToken;
    }

    final (id, expiresAt) = switch (payload) {
      {'sub': final String sub, 'exp': final int exp} when int.tryParse(sub) != null => (
        UserId(int.parse(sub)),
        DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true),
      ),
      _ => (null, null),
    };
    if (id == null || expiresAt == null) return ErrorCodes.invalidToken;
    if (!_clock().toUtc().isBefore(expiresAt)) return ErrorCodes.tokenExpired;

    final user = await store.user(id);
    if (user == null) return ErrorCodes.invalidToken;
    return SignedIn(user: user, expiresAt: expiresAt);
  }

  String? _tokenOf(Request request) {
    final header = request.headers['Authorization']?.firstOrNull;
    const prefix = 'bearer ';
    if (header == null || header.length <= prefix.length) return null;
    if (header.substring(0, prefix.length).toLowerCase() != prefix) return null;
    return header.substring(prefix.length).trim();
  }

  Response _unauthorized(String code) {
    final response = errorResponse(ErrorDto(code: code));
    return response.copyWith(headers: response.headers.transform((headers) => headers['WWW-Authenticate'] = ['Bearer']));
  }
}
