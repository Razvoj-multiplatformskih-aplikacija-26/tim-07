import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';

import 'exceptions.dart';

/// Opšta poruka kada kod nije poznat ovoj verziji aplikacije ili je greška
/// neočekivana. Nikad ne sadrži tehnički tekst.
const genericErrorMessage = 'Došlo je do greške. Pokušajte ponovo.';

/// Nema mreže ili server ne radi.
const serverUnreachableMessage = 'Server trenutno nije dostupan.';

/// Prijava je istekla (`token_expired`); aplikacija vraća korisnika na prijavu.
const sessionExpiredMessage = 'Prijava je istekla. Prijavite se ponovo.';

/// Prijava bez e-pošte ili lozinke; server se ne zove.
const credentialsRequiredMessage = 'Unesite e-mail i lozinku.';

/// Korisnik se prijavio u aplikaciju koja nije za njegovu ulogu (T45: `canSignIn`).
String signInNotAllowedMessage(ClientApp app) => switch (app) {
  ClientApp.mobile =>
      'Ova aplikacija je za korisnike. Osoblje se prijavljuje u backoffice.',
  ClientApp.backoffice =>
      'Backoffice je za vlasnike i administratore sportskih objekata.',
};

/// Broj sati sa ispravnim oblikom reči: 1 sat, 2 sata, 5 sati, 21 sat, 11 sati.
String hoursLabel(int hours) {
  final lastTwo = hours.abs() % 100;
  final last = hours.abs() % 10;
  if (last == 1 && lastTwo != 11) return '$hours sat';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$hours sata';
  }
  return '$hours sati';
}

/// Poruka za korisnika iz koda i podataka greške.
///
/// Jedino mesto gde se tekst pravi: koristi ga i lokalna provera pravila
/// (`validationMessage`) i greška koju pošalje server, pa korisnik vidi istu
/// poruku bez obzira ko je pravilo proverio. Kod koji ova verzija ne poznaje
/// (aplikacija starija od servera) daje [genericErrorMessage], bez izuzetka i
/// bez koda u tekstu.
String errorMessage(ErrorDto error) => switch (error.code) {
  ErrorCodes.invalidTimeRange => 'Kraj termina mora biti posle početka.',
  ErrorCodes.reservationInPast => 'Termin rezervacije mora biti u budućnosti.',
  ErrorCodes.checkInNotAllowed => _checkInMessage(error),
  ErrorCodes.cancellationDeadlineExpired => _cancellationMessage(error),
  ErrorCodes.invalidStatusTransition =>
    'Trenutni status rezervacije ne dozvoljava ovu radnju.',
  ErrorCodes.invalidApprovalTransition =>
    'Ova promena odobrenja terena nije moguća.',
  ErrorCodes.invalidDuration => 'Trajanje rezervacije mora biti pozitivno.',
  ErrorCodes.outsideWorkingHours => 'Termin je van radnog vremena terena.',
  ErrorCodes.fieldBlocked => 'Teren je blokiran u izabranom terminu.',
  ErrorCodes.slotTaken => 'Termin se preklapa sa postojećom rezervacijom.',
  ErrorCodes.fieldUnavailable =>
    'Teren trenutno nije dostupan za rezervisanje.',
  ErrorCodes.invalidBlockRange => 'Kraj blokade mora biti posle početka.',
  ErrorCodes.blockInPast => 'Blokada mora da obuhvata budući termin.',
  ErrorCodes.blockOverlapsReservation =>
    'U izabranom periodu već postoji potvrđena rezervacija.',
  ErrorCodes.forbidden => 'Nemate pravo na ovu radnju.',
  ErrorCodes.notFound => 'Traženi zapis nije pronađen.',
  ErrorCodes.unauthenticated => 'Prijavite se da biste nastavili.',
  ErrorCodes.invalidToken => 'Prijava nije važeća. Prijavite se ponovo.',
  ErrorCodes.tokenExpired => sessionExpiredMessage,
  ErrorCodes.invalidCredentials => 'Pogrešan e-mail ili lozinka.',
  ErrorCodes.accountDeactivated =>
      'Nalog je deaktiviran. Obratite se administratoru.',
  ErrorCodes.badRequest => 'Uneti podaci nisu ispravni.',
  ErrorCodes.payloadTooLarge => 'Poslati podaci su preveliki.',
  _ => genericErrorMessage,
};

String _cancellationMessage(ErrorDto error) {
  final hours = error.detailInt(ErrorDetailKeys.hours);
  if (hours == null || hours <= 0) {
    return 'Rok za otkazivanje rezervacije je istekao.';
  }
  return 'Rezervaciju nije moguće otkazati manje od ${hoursLabel(hours)} pre početka.';
}

String _checkInMessage(ErrorDto error) {
  final opens = error.detailInt(ErrorDetailKeys.opensHours);
  final closes = error.detailInt(ErrorDetailKeys.closesHours);
  if (opens == null || closes == null) {
    return 'Dolazak trenutno nije moguće potvrditi.';
  }
  return 'Dolazak je moguće potvrditi od $opens do ${hoursLabel(closes)} pre početka termina.';
}

/// Poruka za pravilo koje je klijent sam proverio (forma, dugme „Otkaži“).
///
/// Prolazi kroz isti [errorMessage] kao greška sa servera.
String validationMessage(ReservationValidationError error) =>
    errorMessage(error.toErrorDto());

/// Poruka za bilo koju grešku koju Bloc uhvati.
///
/// Nikad ne vraća tehnički tekst (`Bad state: …`, `SocketException`, SQL),
/// samo poruku za korisnika.
String describeError(Object error) => switch (error) {
  ReservationRuleViolation(:final error) => validationMessage(error),
  BlockedPeriodRuleViolation(:final error) => errorMessage(error.toErrorDto()),
  ServerRejectedException(:final error) => errorMessage(error),
  ServerUnreachableException() => serverUnreachableMessage,
  EntityNotFound() => errorMessage(const ErrorDto(code: ErrorCodes.notFound)),
  ApprovalTransitionNotAllowed() => errorMessage(
    const ErrorDto(code: ErrorCodes.invalidApprovalTransition),
  ),
  // Lažni repozitorijumi (demo podaci) bacaju StateError sa gotovom porukom na
  // srpskom, da simulacija greške u aplikaciji ima čitljiv tekst.
  StateError(:final message) => message,
  _ => genericErrorMessage,
};

/// Da li greška znači da je prijava istekla (aplikacija vraća na prijavu).
bool isSessionExpired(Object error) =>
    error is ServerRejectedException &&
    error.error.code == ErrorCodes.tokenExpired;
