
import '../enums.dart';

/// Pravila dozvoljenih prelaza između statusa rezervacije.
///
/// Ova funkcija proverava samo da li je prelaz dozvoljen.
/// Vremenska pravila i check-in proveravamo zasebno.
bool canTransitionReservationStatus(
    ReservationStatus from,
    ReservationStatus to,
    ) {
  return switch (from) {
    ReservationStatus.pending =>
    to == ReservationStatus.confirmed ||
        to == ReservationStatus.cancelled,

    ReservationStatus.confirmed =>
    to == ReservationStatus.completed ||
        to == ReservationStatus.cancelled,

  // Završena i otkazana rezervacija su konačna stanja.
    ReservationStatus.completed => false,
    ReservationStatus.cancelled => false,
  };
}
