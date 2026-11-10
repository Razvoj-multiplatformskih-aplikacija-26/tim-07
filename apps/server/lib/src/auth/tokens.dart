import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';

final class AuthSession {
  final UserId userId;
  final UserRole role;
  final DateTime expiresAt;

  const AuthSession({required this.userId, required this.role, required this.expiresAt});
}

final class TokenRejected implements Exception {
  final String code;

  const TokenRejected._(this.code);

  static const expired = TokenRejected._('token_expired');
  static const invalid = TokenRejected._('invalid_token');

  @override
  String toString() => 'TokenRejected($code)';
}

final class TokenService {
  final SecretKey _key;
  final Duration ttl;
  final DateTime Function() _clock;

  static const _algorithm = JWTAlgorithm.HS256;

  TokenService({
    required String secret,
    required this.ttl,
    DateTime Function()? clock,
  })  : _key = SecretKey(secret),
        _clock = clock ?? DateTime.now;

  ({String token, DateTime expiresAt}) issue(AppUser user) {
    final now = _clock().toUtc();
    final expiresAt = _fromSeconds(_seconds(now.add(ttl)));

    final token = JWT(
      {
        'role': user.role.name,
        'iat': _seconds(now),
        'exp': _seconds(expiresAt),
      },
      subject: '${user.id.value}',
    ).sign(_key, algorithm: _algorithm, noIssueAt: true);

    return (token: token, expiresAt: expiresAt);
  }

  AuthSession verify(String token) {
    final Map<String, dynamic> payload;
    try {
      if (JWT.decode(token).header?['alg'] != _algorithm.name) {
        throw TokenRejected.invalid;
      }
      final verified = JWT.verify(token, _key, checkExpiresIn: false, checkNotBefore: false);
      if (verified.payload is! Map<String, dynamic>) throw TokenRejected.invalid;
      payload = verified.payload as Map<String, dynamic>;
    } on JWTException {
      throw TokenRejected.invalid;
    } on FormatException {
      throw TokenRejected.invalid;
    } on ArgumentError {
      throw TokenRejected.invalid;
    }

    final session = switch (payload) {
      {'sub': final String sub, 'role': final String role, 'exp': final int exp}
          when int.tryParse(sub) != null && UserRole.values.any((r) => r.name == role) =>
        AuthSession(
          userId: UserId(int.parse(sub)),
          role: UserRole.values.byName(role),
          expiresAt: _fromSeconds(exp),
        ),
      _ => throw TokenRejected.invalid,
    };

    if (!_clock().toUtc().isBefore(session.expiresAt)) {
      throw TokenRejected.expired;
    }
    return session;
  }

  static int _seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;

  static DateTime _fromSeconds(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
