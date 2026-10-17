
import '../enums.dart';
import '../ids.dart';
import '../models/reservation.dart';

/// Proverava da li se dva vremenska intervala preklapaju.
///
/// Intervali su [start, end), što znači da je
/// početak uključen, a kraj isključen.
///
/// Primer:
/// 14:00-16:00 i 16:00-18:00 se NE preklapaju.
bool doTimeRangesOverlap({
  required DateTime firstStart,
  required DateTime firstEnd,
  required DateTime secondStart,
  required DateTime secondEnd,
}) {
  return firstStart.isBefore(secondEnd) &&
      secondStart.isBefore(firstEnd);
}

/// Proverava da li postoji konflikt sa postojećim
/// aktivnim rezervacijama.
///
/// Konflikt postoji kada:
/// 1. Dve rezervacije koriste isti teren u isto vreme.
/// 2. Isti korisnik ima dve rezervacije u isto vreme,
///    čak i ako su tereni različiti.
///
/// Otkazane i završene rezervacije se ignorišu.
bool hasReservationOverlap({
  required FieldId fieldId,
  required UserId userId,
  required DateTime startTime,
  required DateTime endTime,
  required Iterable<Reservation> existingReservations,
}) {
  for (final reservation in existingReservations) {
    if (reservation.status != ReservationStatus.pending &&
        reservation.status != ReservationStatus.confirmed) {
      continue;
    }

    final sameField = reservation.fieldId == fieldId;
    final sameUser = reservation.userId == userId;

    if (!sameField && !sameUser) {
      continue;
    }

    if (doTimeRangesOverlap(
      firstStart: startTime,
      firstEnd: endTime,
      secondStart: reservation.startTime,
      secondEnd: reservation.endTime,
    )) {
      return true;
    }
  }

  return false;
}
