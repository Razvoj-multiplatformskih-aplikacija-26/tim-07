import '../enums.dart';
import '../ids.dart';
import '../models/reservation.dart';
import 'reservation_overlap.dart';

/// Zašto blokada terena nije dozvoljena.
sealed class BlockedPeriodError {
  const BlockedPeriodError();

  String get message;
}

/// Kraj blokade nije posle početka.
final class InvalidBlockRange extends BlockedPeriodError {
  const InvalidBlockRange();

  @override
  String get message => 'Kraj blokade mora biti posle početka.';
}

/// Blokada je cela u prošlosti, pa ne blokira ništa.
final class BlockInPast extends BlockedPeriodError {
  const BlockInPast();

  @override
  String get message => 'Blokada mora da obuhvata budući termin.';
}

/// U izabranom periodu već postoji potvrđena rezervacija. Blokada je ne sme
/// pregaziti: vlasnik je prvo otkazuje, pa tek onda blokira teren.
final class BlockOverlapsConfirmedReservation extends BlockedPeriodError {
  const BlockOverlapsConfirmedReservation();

  @override
  String get message =>
      'U izabranom periodu već postoji potvrđena rezervacija.';
}

/// Izuzetak koji repozitorijum baca kada blokada krši pravilo.
final class BlockedPeriodRuleViolation implements Exception {
  final BlockedPeriodError error;

  const BlockedPeriodRuleViolation(this.error);

  @override
  String toString() => error.message;
}

/// Da li vlasnik sme da blokira teren u datom periodu.
///
/// `null` znači da sme. Pravila (redom):
/// 1. kraj mora biti posle početka;
/// 2. blokada ne sme da bude cela u prošlosti (period koji je već počeo, a
///    traje, može da se blokira od sada);
/// 3. blokada ne sme da se preklapa sa **potvrđenom** rezervacijom tog terena.
///    Rezervacija na čekanju ne smeta: vlasnik je može odbiti. Isto pravilo
///    proverava server pre upisa, a klijent ga koristi da odmah prikaže razlog.
///
/// Posle blokade nove rezervacije u tom periodu odbija `validateReservationSlot`
/// (`FieldBlocked`), isto kao i na serveru.
///
/// Stanja rezervacija treba da su već ažurna (`resolveReservationStatus`):
/// rezervacija koja je sama otkazana ili završena ne smeta.
BlockedPeriodError? validateBlockedPeriod({
  required FieldId fieldId,
  required DateTime startTime,
  required DateTime endTime,
  required DateTime now,
  required Iterable<Reservation> reservations,
}) {
  if (!endTime.isAfter(startTime)) {
    return const InvalidBlockRange();
  }

  if (!endTime.isAfter(now)) {
    return const BlockInPast();
  }

  for (final reservation in reservations) {
    if (reservation.fieldId != fieldId ||
        reservation.status != ReservationStatus.confirmed) {
      continue;
    }

    if (doTimeRangesOverlap(
      firstStart: startTime,
      firstEnd: endTime,
      secondStart: reservation.startTime,
      secondEnd: reservation.endTime,
    )) {
      return const BlockOverlapsConfirmedReservation();
    }
  }

  return null;
}
