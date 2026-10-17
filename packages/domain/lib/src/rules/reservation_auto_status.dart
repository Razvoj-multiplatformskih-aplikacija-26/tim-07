
import '../enums.dart';
import '../models/reservation.dart';

/// Proverava da li je check-in izvršen u dozvoljenom periodu.
bool hasValidCheckIn(Reservation reservation) {
  final checkedInAt = reservation.checkedInAt;

  if (checkedInAt == null) {
    return false;
  }

  return !checkedInAt.isBefore(reservation.checkInOpensAt) &&
      checkedInAt.isBefore(reservation.checkInDeadline);
}

/// Određuje status rezervacije na osnovu trenutnog vremena.
///
/// Funkcija ne menja postojeću rezervaciju i ne poziva
/// DateTime.now(), pa je pogodna za unit testiranje.
ReservationStatus resolveReservationStatus(
    Reservation reservation,
    DateTime now,
    ) {
  final status = reservation.status;

  // Završena i otkazana rezervacija su konačna stanja.
  if (status == ReservationStatus.completed ||
      status == ReservationStatus.cancelled) {
    return status;
  }

  // Rezervacija na čekanju se otkazuje ako vlasnik
  // nije potvrdio rezervaciju pre isteka roka.
  if (status == ReservationStatus.pending) {
    if (!now.isBefore(reservation.checkInDeadline)) {
      return ReservationStatus.cancelled;
    }

    return ReservationStatus.pending;
  }

  // Potvrđena rezervacija bez validnog check-in-a
  // automatski se otkazuje kada istekne rok.
  if (!hasValidCheckIn(reservation) &&
      !now.isBefore(reservation.checkInDeadline)) {
    return ReservationStatus.cancelled;
  }

  // Potvrđena rezervacija sa validnim check-in-om
  // automatski se završava nakon isteka termina.
  if (hasValidCheckIn(reservation) &&
      !now.isBefore(reservation.endTime)) {
    return ReservationStatus.completed;
  }

  return ReservationStatus.confirmed;
}
