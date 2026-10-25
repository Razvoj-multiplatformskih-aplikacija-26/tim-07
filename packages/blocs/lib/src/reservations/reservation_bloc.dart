
import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';

import 'reservation_event.dart';
import 'reservation_state.dart';

/// Upravlja rezervacijama koristeci repository port.
///
/// Ne zna da li podaci dolaze iz memorije, baze ili API-ja.
final class ReservationBloc
    extends Bloc<ReservationEvent, ReservationState> {
  final ReservationRepository repository;
  Future<List<Reservation>> Function()? _lastQuery;

  ReservationBloc({required this.repository})
      : super(const ReservationInitial()) {
    on<ReservationsRequested>(_onReservationsRequested);
    on<UserReservationsRequested>(_onUserReservationsRequested);
    on<FieldReservationsRequested>(_onFieldReservationsRequested);
    on<ReservationCreateRequested>(_onReservationCreateRequested);
    on<ReservationConfirmRequested>(_onReservationConfirmRequested);
    on<ReservationCancelRequested>(_onReservationCancelRequested);
    on<ReservationCheckInRequested>(_onReservationCheckInRequested);
  }

  Future<void> _loadReservations(
      Emitter<ReservationState> emit,
      Future<List<Reservation>> Function() fetch,
      ) async {
    _lastQuery = fetch;
    emit(const ReservationLoading());

    try {
      final reservations = await fetch();

      if (reservations.isEmpty) {
        emit(const ReservationEmpty());
      } else {
        emit(ReservationLoaded(reservations));
      }
    } catch (error) {
      emit(ReservationError(error.toString()));
    }
  }

  Future<void> _onReservationsRequested(
      ReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
      repository.getReservations,
    );
  }

  Future<void> _onUserReservationsRequested(
      UserReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
          () => repository.getReservationsByUser(event.userId),
    );
  }

  Future<void> _onFieldReservationsRequested(
      FieldReservationsRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _loadReservations(
      emit,
          () => repository.getReservationsByField(event.fieldId),
    );
  }

  Future<void> _onReservationCreateRequested(
      ReservationCreateRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.createReservation(
        fieldId: event.fieldId,
        userId: event.userId,
        startTime: event.startTime,
        endTime: event.endTime,
      ),
    );
  }

  Future<void> _onReservationConfirmRequested(
      ReservationConfirmRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.updateReservationStatus(
        reservationId: event.reservationId,
        status: ReservationStatus.confirmed,
      ),
    );
  }

  Future<void> _onReservationCancelRequested(
      ReservationCancelRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.cancelReservation(event.reservationId),
    );
  }

  Future<void> _onReservationCheckInRequested(
      ReservationCheckInRequested event,
      Emitter<ReservationState> emit,
      ) async {
    await _performAction(
      emit,
          () => repository.checkIn(event.reservationId),
    );
  }

  Future<void> _performAction(
      Emitter<ReservationState> emit,
      Future<Reservation> Function() action,
      ) async {
    emit(const ReservationLoading());

    try {
      await action();

      final reload = _lastQuery ?? repository.getReservations;
      final reservations = await reload();

      if (reservations.isEmpty) {
        emit(const ReservationEmpty());
      } else {
        emit(ReservationLoaded(reservations));
      }
    } catch (error) {
      emit(ReservationError(error.toString()));
    }
  }
}
