import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

void main() {
  const secret = '0123456789abcdef0123456789abcdef';
  var now = DateTime.utc(2030, 6, 3, 10);
  final service = TokenService(secret: secret, ttl: const Duration(minutes: 120), clock: () => now);
  final owner = AppUser(
    id: const UserId(3),
    firstName: 'Vlada',
    lastName: 'Vlasnik',
    email: 'vlada@example.com',
    phoneNumber: '060',
    dateOfBirth: DateTime.utc(1985),
    role: UserRole.owner,
    createdAt: DateTime.utc(2026),
  );

  setUp(() => now = DateTime.utc(2030, 6, 3, 10));

  Matcher rejectedWith(TokenRejected expected) =>
      throwsA(isA<TokenRejected>().having((e) => e.code, 'code', expected.code));

  test('izdat token vraća id i ulogu, ističe posle trajanja iz podešavanja', () {
    final issued = service.issue(owner);
    final session = service.verify(issued.token);

    expect(session.userId, const UserId(3));
    expect(session.role, UserRole.owner);
    expect(issued.expiresAt, DateTime.utc(2030, 6, 3, 12));
    expect(session.expiresAt, issued.expiresAt);
  });

  test('posle isteka → token_expired', () {
    final issued = service.issue(owner);

    now = DateTime.utc(2030, 6, 3, 11, 59, 59);
    expect(service.verify(issued.token).userId, const UserId(3));

    now = DateTime.utc(2030, 6, 3, 12);
    expect(() => service.verify(issued.token), rejectedWith(TokenRejected.expired));
  });

  test('izmenjen sadržaj (npr. uloga) → invalid_token', () {
    final parts = service.issue(owner).token.split('.');
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
        as Map<String, dynamic>;
    payload['role'] = 'admin';
    final forged =
        '${parts[0]}.${base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '')}.${parts[2]}';

    expect(() => service.verify(forged), rejectedWith(TokenRejected.invalid));
  });

  test('token potpisan drugom tajnom → invalid_token', () {
    final other = TokenService(
      secret: 'neka-druga-tajna-koja-ima-32-znaka!',
      ttl: const Duration(minutes: 120),
      clock: () => now,
    );

    expect(() => service.verify(other.issue(owner).token), rejectedWith(TokenRejected.invalid));
  });

  test('algoritam "none" i besmislen tekst → invalid_token', () {
    final unsigned = JWT({'role': 'admin', 'exp': 9999999999}, subject: '1')
        .sign(SecretKey(secret), algorithm: JWTAlgorithm.HS512);

    expect(() => service.verify(unsigned), rejectedWith(TokenRejected.invalid));
    expect(() => service.verify('eyJhbGciOiJub25lIn0.e30.'), rejectedWith(TokenRejected.invalid));
    expect(() => service.verify('nije-token'), rejectedWith(TokenRejected.invalid));
  });
}
