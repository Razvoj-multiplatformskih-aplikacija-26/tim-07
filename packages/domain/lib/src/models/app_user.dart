
import '../enums.dart';
import '../ids.dart';

/// Korisnik platforme Terenzo.
///
/// Isti model predstavlja običnog korisnika,
/// vlasnika terena i administratora.
final class AppUser {
  final UserId id;
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final DateTime dateOfBirth;
  final UserRole role;
  final DateTime createdAt;

  /// Deaktiviran nalog se ne može prijaviti, a postojeća prijava prestaje da
  /// važi. Deaktivira ga administrator (`canDeactivateUser`).
  final bool isActive;

  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.role,
    required this.createdAt,
    this.isActive = true,
  });

  /// Puno ime korisnika.
  String get fullName => '$firstName $lastName';

  /// Godine se računaju iz datuma rođenja.
  int ageAt(DateTime date) {
    var age = date.year - dateOfBirth.year;

    if (date.month < dateOfBirth.month ||
        (date.month == dateOfBirth.month &&
            date.day < dateOfBirth.day)) {
      age--;
    }

    return age;
  }

  /// Kreira novu instancu sa izmenjenim podacima.
  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    DateTime? dateOfBirth,
    UserRole? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

