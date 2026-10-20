import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class ReservationSelectionEvent extends Equatable {
  const ReservationSelectionEvent();

  @override
  List<Object?> get props => [];
}

final class ReservationSelected extends ReservationSelectionEvent {
  final ReservationId reservationId;

  const ReservationSelected(this.reservationId);

  @override
  List<Object?> get props => [reservationId];
}

final class ReservationSelectionCleared extends ReservationSelectionEvent {
  const ReservationSelectionCleared();
}

final class ReservationSelectionState extends Equatable {
  final ReservationId? selectedId;

  const ReservationSelectionState({this.selectedId});

  @override
  List<Object?> get props => [selectedId];
}

final class ReservationSelectionBloc
    extends Bloc<ReservationSelectionEvent, ReservationSelectionState> {
  ReservationSelectionBloc() : super(const ReservationSelectionState()) {
    on<ReservationSelected>(
      (event, emit) =>
          emit(ReservationSelectionState(selectedId: event.reservationId)),
    );
    on<ReservationSelectionCleared>(
      (event, emit) => emit(const ReservationSelectionState()),
    );
  }
}
