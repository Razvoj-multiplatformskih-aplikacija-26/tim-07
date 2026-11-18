
import 'package:equatable/equatable.dart';
import 'package:domain/domain.dart';

/// Osnovna klasa za sve događaje rezervacija.
sealed class ReservationEvent extends Equatable {
  const ReservationEvent();

  @override
  List<Object?> get props => [];
}

/// Učitavanje svih rezervacija.
final class ReservationsRequested extends ReservationEvent {
  const ReservationsRequested();
}

/// Učitavanje rezervacija jednog korisnika.
final class UserReservationsRequested extends ReservationEvent {
  final UserId userId;

  const UserReservationsRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Učitavanje rezervacija jednog terena.
final class FieldReservationsRequested extends ReservationEvent {
  final FieldId fieldId;

  const FieldReservationsRequested(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

/// Kreiranje nove rezervacije.
final class ReservationCreateRequested extends ReservationEvent {
  final FieldId fieldId;
  final UserId userId;
  final DateTime startTime;
  final DateTime endTime;

  const ReservationCreateRequested({
    required this.fieldId,
    required this.userId,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [
    fieldId,
    userId,
    startTime,
    endTime,
  ];
}

/// Potvrđivanje rezervacije.
final class ReservationConfirmRequested extends ReservationEvent {
  final ReservationId reservationId;

  const ReservationConfirmRequested(this.reservationId);

  @override
  List<Object?> get props => [reservationId];
}

/// Otkazivanje rezervacije.
final class ReservationCancelRequested extends ReservationEvent {
  final ReservationId reservationId;

  const ReservationCancelRequested(this.reservationId);

  @override
  List<Object?> get props => [reservationId];
}

/// Check-in korisnika za rezervaciju.
final class ReservationCheckInRequested extends ReservationEvent {
  final ReservationId reservationId;

  const ReservationCheckInRequested(this.reservationId);

  @override
  List<Object?> get props => [reservationId];
}
