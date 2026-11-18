import 'json.dart';

/// Nalog korisnika (bez lozinke i heša: oni nikad ne napuštaju server).
final class UserDto {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  /// Kod uloge iz `RoleCodes`.
  final String role;

  /// Samo u listi naloga za administratora.
  final String? phoneNumber;
  final DateTime? createdAt;

  const UserDto({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.createdAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'role': role,
    'phoneNumber': ?phoneNumber,
    if (createdAt case final createdAt?) 'createdAt': instantToJson(createdAt),
  };

  factory UserDto.fromJson(Map<String, Object?> json) => UserDto(
    id: jsonInt(json, 'id'),
    firstName: jsonString(json, 'firstName'),
    lastName: jsonString(json, 'lastName'),
    email: jsonString(json, 'email'),
    role: jsonString(json, 'role'),
    phoneNumber: jsonOptionalString(json, 'phoneNumber'),
    createdAt: jsonOptionalInstant(json, 'createdAt'),
  );
}

/// Telo zahteva `POST /auth/login`.
final class LoginRequestDto {
  final String email;
  final String password;

  const LoginRequestDto({required this.email, required this.password});

  Map<String, Object?> toJson() => {'email': email, 'password': password};

  factory LoginRequestDto.fromJson(Map<String, Object?> json) =>
      LoginRequestDto(
        email: jsonString(json, 'email'),
        password: jsonString(json, 'password'),
      );
}

/// Odgovor na prijavu (sa tokenom) i na `GET /auth/me` (bez tokena).
final class SessionDto {
  final UserDto user;
  final DateTime expiresAt;
  final String? token;

  const SessionDto({required this.user, required this.expiresAt, this.token});

  Map<String, Object?> toJson() => {
    'user': user.toJson(),
    'expiresAt': instantToJson(expiresAt),
    'token': ?token,
  };

  factory SessionDto.fromJson(Map<String, Object?> json) => SessionDto(
    user: UserDto.fromJson(jsonObject(json['user'])),
    expiresAt: jsonInstant(json, 'expiresAt'),
    token: jsonOptionalString(json, 'token'),
  );
}
