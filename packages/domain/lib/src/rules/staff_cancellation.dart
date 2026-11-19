import '../enums.dart';
import '../models/app_user.dart';
import '../models/reservation.dart';
import 'reservation_validation.dart';
import 'reservation_validation_error.dart';

ReservationValidationError? validateCancellationBy({
  required AppUser user,
  required Reservation reservation,
  required DateTime now,
}) {
  if (user.role == UserRole.user) {
    return validateCancellation(reservation: reservation, now: now);
  }
  if (!reservation.isActive) {
    return const InvalidReservationStatus();
  }
  if (!now.isBefore(reservation.startTime)) {
    return const CancellationDeadlineExpired();
  }
  return null;
}
