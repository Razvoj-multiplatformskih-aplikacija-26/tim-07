
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Osnovna klasa za sva stanja rezervacija.
sealed class ReservationState extends Equatable {
  const ReservationState();

  @override
  List<Object?> get props => [];
}

/// Pocetno stanje, pre bilo kakvog ucitavanja.
final class ReservationInitial extends ReservationState {
  const ReservationInitial();
}

/// Rezervacije se trenutno ucitavaju.
final class ReservationLoading extends ReservationState {
  const ReservationLoading();
}

/// Rezervacije su uspesno ucitane.
final class ReservationLoaded extends ReservationState {
  final List<Reservation> reservations;

  const ReservationLoaded(this.reservations);

  @override
  List<Object?> get props => [reservations];
}

/// Nema rezervacija za prikaz.
final class ReservationEmpty extends ReservationState {
  const ReservationEmpty();
}

/// Doslo je do greske prilikom rada sa rezervacijama.
final class ReservationError extends ReservationState {
  final String message;

  const ReservationError(this.message);

  @override
  List<Object?> get props => [message];
}
