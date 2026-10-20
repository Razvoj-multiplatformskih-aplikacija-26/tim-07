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

final class ReservationSelectionMoved extends ReservationSelectionEvent {
  final int offset;
  final List<ReservationId> order;

  const ReservationSelectionMoved({required this.offset, required this.order});

  @override
  List<Object?> get props => [offset, order];
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
    on<ReservationSelectionMoved>(_onMoved);
  }

  void _onMoved(
    ReservationSelectionMoved event,
    Emitter<ReservationSelectionState> emit,
  ) {
    final order = event.order;
    if (order.isEmpty || event.offset == 0) {
      return;
    }

    final selected = state.selectedId;
    final index = selected == null ? -1 : order.indexOf(selected);
    final last = order.length - 1;

    var start = index;
    if (index == -1) {
      start = event.offset > 0 ? -1 : order.length;
    }

    var next = start + event.offset;
    if (next < 0) {
      next = 0;
    }
    if (next > last) {
      next = last;
    }

    emit(ReservationSelectionState(selectedId: order[next]));
  }
}
