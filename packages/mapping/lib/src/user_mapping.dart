import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';

extension AppUserMapping on AppUser {
  /// Osnovni podaci za prijavljenog korisnika. Za listu naloga koju vidi
  /// administrator `includeContact` dodaje telefon i datum registracije.
  /// Datum rođenja se nikad ne šalje.
  UserDto toDto({bool includeContact = false}) => UserDto(
    id: id.value,
    firstName: firstName,
    lastName: lastName,
    email: email,
    role: roleToCode(role),
    phoneNumber: includeContact ? phoneNumber : null,
    createdAt: includeContact ? createdAt : null,
    isActive: includeContact ? isActive : null,
  );
}

extension UserDtoMapping on UserDto {
  /// Baca [UnknownCodeException] za nepoznatu ulogu.
  ///
  /// Server ne šalje datum rođenja, a telefon i datum registracije šalje samo
  /// administratoru. Ono što nije stiglo popunjava se neutralnom vrednošću
  /// (prazan tekst i `DateTime.utc(1970)`): klijent ne sme da je prikazuje niti
  /// da se oslanja na nju.
  AppUser toDomain() => AppUser(
    id: UserId(id),
    firstName: firstName,
    lastName: lastName,
    email: email,
    phoneNumber: phoneNumber ?? '',
    dateOfBirth: DateTime.utc(1970),
    role: requireKnown(roleFromCode(role), 'role', role),
    createdAt: createdAt ?? DateTime.utc(1970),
    // Stanje stiže samo u listi za administratora; bez njega je nalog aktivan.
    isActive: isActive ?? true,
  );
}
