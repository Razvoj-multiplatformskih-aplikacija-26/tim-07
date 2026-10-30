import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';
import '../models/reservation.dart';
import 'reservation_blocked_periods.dart';
import 'reservation_overlap.dart';
import 'reservation_validation_error.dart';
import 'reservation_working_hours.dart';

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

/// Proverava da li se termin može rezervisati.
///
/// Pravila se proveravaju redom: ispravnost vremena, preklapanje sa
/// postojećim rezervacijama, blokirani periodi i radno vreme terena.
/// Prva prekršena stavka se vraća kao tipizirana greška, a null znači
/// da je termin slobodan za podatke koje funkcija dobija.
///
/// Klijent prosleđuje samo rezervacije koje poznaje, pa konačnu odluku
/// o preklapanju sa tuđim rezervacijama donosi server.
ReservationValidationError? validateReservationSlot({
  required FieldId fieldId,
  required UserId userId,
  required DateTime startTime,
  required DateTime endTime,
  required DateTime now,
  required Iterable<Reservation> existingReservations,
  required Iterable<FieldSchedule> schedules,
  Iterable<BlockedPeriod> blockedPeriods = const [],
}) {
  final timeError = validateReservationTime(
    startTime: startTime,
    endTime: endTime,
    now: now,
  );

  if (timeError != null) {
    return timeError;
  }

  if (hasReservationOverlap(
    fieldId: fieldId,
    userId: userId,
    startTime: startTime,
    endTime: endTime,
    existingReservations: existingReservations,
  )) {
    return const SlotAlreadyTaken();
  }

  if (hasBlockedPeriodOverlap(
    fieldId: fieldId,
    startTime: startTime,
    endTime: endTime,
    blockedPeriods: blockedPeriods,
  )) {
    return const FieldBlocked();
  }

  if (!isReservationWithinWorkingHours(
    fieldId: fieldId,
    startTime: startTime,
    endTime: endTime,
    schedules: schedules,
  )) {
    return const OutsideWorkingHours();
  }

  return null;
}
