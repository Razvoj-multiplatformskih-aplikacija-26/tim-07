
import '../enums.dart';
import '../models/reservation.dart';
import 'reservation_validation_error.dart';

/// Proverava da li je vremenski interval rezervacije ispravan.
///
/// null znači da je validacija uspešna.
/// U suprotnom vraća konkretnu tipiziranu grešku.
ReservationValidationError? validateReservationTime({
  required DateTime startTime,
  required DateTime endTime,
  required DateTime now,
}) {
  if (!endTime.isAfter(startTime)) {
    return const InvalidTimeRange();
  }

  if (!startTime.isAfter(now)) {
    return const ReservationInPast();
  }

  return null;
}

/// Proverava da li korisnik sme da izvrši check-in.
///
/// Check-in je dozvoljen od 24 sata pre početka
/// do trenutka 5 sati pre početka (isključivo).
ReservationValidationError? validateCheckIn({
  required Reservation reservation,
  required DateTime now,
}) {
  if (reservation.status != ReservationStatus.confirmed) {
    return const InvalidReservationStatus();
  }

  if (now.isBefore(reservation.checkInOpensAt) ||
      !now.isBefore(reservation.checkInDeadline)) {
    return const CheckInNotAllowed();
  }

  if (reservation.isCheckedIn) {
    return const InvalidReservationStatus();
  }

  return null;
}

/// Proverava da li korisnik sme da otkaže rezervaciju.
///
/// Otkazivanje je moguće samo pre isteka roka
/// od 5 sati pre početka termina.
ReservationValidationError? validateCancellation({
  required Reservation reservation,
  required DateTime now,
}) {
  if (reservation.status != ReservationStatus.pending &&
      reservation.status != ReservationStatus.confirmed) {
    return const InvalidReservationStatus();
  }

  if (!now.isBefore(reservation.checkInDeadline)) {
    return const CancellationDeadlineExpired();
  }

  return null;
}
