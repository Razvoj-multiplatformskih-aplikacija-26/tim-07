/// Tipizirane greške koje mogu nastati prilikom
/// validacije rezervacije.
///
/// Svaka greška ima svoj tip, pa aplikacija može
/// precizno da reaguje bez poređenja stringova.
sealed class ReservationValidationError {
  const ReservationValidationError();

  String get message;
}

/// Kraj termina mora biti posle početka.
final class InvalidTimeRange extends ReservationValidationError {
  const InvalidTimeRange();

  @override
  String get message => 'Kraj termina mora biti posle početka.';
}

/// Nije dozvoljeno rezervisati termin u prošlosti.
final class ReservationInPast extends ReservationValidationError {
  const ReservationInPast();

  @override
  String get message => 'Termin rezervacije mora biti u budućnosti.';
}

/// Check-in je moguć samo u dozvoljenom periodu.
final class CheckInNotAllowed extends ReservationValidationError {
  const CheckInNotAllowed();

  @override
  String get message =>
      'Check-in je dozvoljen od 24 do 5 sati pre početka termina.';
}

/// Rok za otkazivanje rezervacije je istekao.
final class CancellationDeadlineExpired extends ReservationValidationError {
  const CancellationDeadlineExpired();

  @override
  String get message =>
      'Rezervaciju nije moguće otkazati manje od 5 sati pre početka.';
}

/// Rezervacija nije u odgovarajućem statusu za operaciju.
final class InvalidReservationStatus extends ReservationValidationError {
  const InvalidReservationStatus();

  @override
  String get message =>
      'Trenutni status rezervacije ne dozvoljava ovu operaciju.';
}

/// Trajanje rezervacije mora biti pozitivno.
final class InvalidReservationDuration extends ReservationValidationError {
  const InvalidReservationDuration();

  @override
  String get message => 'Trajanje rezervacije mora biti pozitivno.';
}

/// Termin nije u potpunosti unutar radnog vremena terena.
final class OutsideWorkingHours extends ReservationValidationError {
  const OutsideWorkingHours();

  @override
  String get message => 'Termin je van radnog vremena terena.';
}

/// Teren je blokiran (održavanje, događaj) u izabranom terminu.
final class FieldBlocked extends ReservationValidationError {
  const FieldBlocked();

  @override
  String get message => 'Teren je blokiran u izabranom terminu.';
}

/// Termin se preklapa sa postojećom aktivnom rezervacijom.
final class SlotAlreadyTaken extends ReservationValidationError {
  const SlotAlreadyTaken();

  @override
  String get message => 'Termin se preklapa sa postojećom rezervacijom.';
}
