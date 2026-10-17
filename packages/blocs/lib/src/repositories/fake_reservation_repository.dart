
import 'package:domain/domain.dart';

/// Repozitorijum koji cuva rezervacije u memoriji.
///
/// Ne koristi bazu podataka ni backend.
final class FakeReservationRepository implements ReservationRepository {
  final List<Reservation> _reservations;
  final List<SportsField> _fields;
  final List<FieldSchedule> _schedules;
  final List<BlockedPeriod> _blockedPeriods;
  final DateTime Function() _clock;

  int _nextReservationId;

  FakeReservationRepository({
    List<Reservation> reservations = const [],
    List<SportsField> fields = const [],
    List<FieldSchedule> schedules = const [],
    List<BlockedPeriod> blockedPeriods = const [],
    DateTime Function()? clock,
  })  : _reservations = List.of(reservations),
        _fields = List.of(fields),
        _schedules = List.of(schedules),
        _blockedPeriods = List.of(blockedPeriods),
        _clock = clock ?? DateTime.now,
        _nextReservationId = reservations.fold<int>(
          0,
              (maxId, reservation) =>
          reservation.id.value > maxId
              ? reservation.id.value
              : maxId,
        ) +
            1;

  /// Automatski osvezava statuse prema trenutnom vremenu.
  void _refreshStatuses() {
    final now = _clock();

    for (var i = 0; i < _reservations.length; i++) {
      final reservation = _reservations[i];
      final newStatus = resolveReservationStatus(reservation, now);

      if (newStatus != reservation.status) {
        _reservations[i] = reservation.copyWith(status: newStatus);
      }
    }
  }

  Reservation _findReservation(ReservationId id) {
    for (final reservation in _reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }

    throw StateError('Rezervacija nije pronadjena.');
  }

  SportsField _findField(FieldId id) {
    for (final field in _fields) {
      if (field.id == id) {
        return field;
      }
    }

    throw StateError('Teren nije pronadjen.');
  }

  @override
  Future<List<Reservation>> getReservations() async {
    _refreshStatuses();
    return List.unmodifiable(_reservations);
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    _refreshStatuses();

    return List.unmodifiable(
      _reservations.where((r) => r.userId == userId),
    );
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    _refreshStatuses();

    return List.unmodifiable(
      _reservations.where((r) => r.fieldId == fieldId),
    );
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    _refreshStatuses();

    for (final reservation in _reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }

    return null;
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _refreshStatuses();

    final now = _clock();
    final field = _findField(fieldId);

    if (!field.isActive) {
      throw StateError('Teren trenutno nije aktivan.');
    }

    final timeError = validateReservationTime(
      startTime: startTime,
      endTime: endTime,
      now: now,
    );

    if (timeError != null) {
      throw StateError(timeError.message);
    }

    if (hasReservationOverlap(
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      existingReservations: _reservations,
    )) {
      throw StateError('Termin se preklapa sa postojecom rezervacijom.');
    }

    if (hasBlockedPeriodOverlap(
      fieldId: fieldId,
      startTime: startTime,
      endTime: endTime,
      blockedPeriods: _blockedPeriods,
    )) {
      throw StateError('Teren je blokiran u izabranom terminu.');
    }

    if (!isReservationWithinWorkingHours(
      fieldId: fieldId,
      startTime: startTime,
      endTime: endTime,
      schedules: _schedules,
    )) {
      throw StateError('Termin je van radnog vremena terena.');
    }

    // Cena se racuna proporcionalno trajanju.
    final durationMinutes = endTime.difference(startTime).inMinutes;
    final totalPrice =
    (field.pricePerHour * durationMinutes / 60).round();

    final status = field.confirmationMode == ConfirmationMode.automatic
        ? ReservationStatus.confirmed
        : ReservationStatus.pending;

    final reservation = Reservation(
      id: ReservationId(_nextReservationId++),
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      status: status,
      createdAt: now,
    );

    _reservations.add(reservation);

    return reservation;
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    _refreshStatuses();

    final reservation = _findReservation(reservationId);

    if (!canTransitionReservationStatus(
      reservation.status,
      status,
    )) {
      throw StateError('Promena statusa nije dozvoljena.');
    }

    // Rucno potvrdjivanje mora biti pre roka od 5 sati.
    if (status == ReservationStatus.confirmed &&
        !_clock().isBefore(reservation.checkInDeadline)) {
      throw StateError('Rok za potvrdjivanje je istekao.');
    }

    // Za otkazivanje koristimo postojece domensko pravilo.
    if (status == ReservationStatus.cancelled) {
      final error = validateCancellation(
        reservation: reservation,
        now: _clock(),
      );

      if (error != null) {
        throw StateError(error.message);
      }
    }

    // Zavrsavanje rezervacije je automatsko.
    if (status == ReservationStatus.completed) {
      throw StateError(
        'Rezervacija se zavrsava automatski nakon termina.',
      );
    }

    final updated = reservation.copyWith(status: status);
    final index = _reservations.indexWhere(
          (r) => r.id == reservationId,
    );

    _reservations[index] = updated;

    return updated;
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    _refreshStatuses();

    final reservation = _findReservation(reservationId);
    final now = _clock();

    final error = validateCheckIn(
      reservation: reservation,
      now: now,
    );

    if (error != null) {
      throw StateError(error.message);
    }

    final updated = reservation.copyWith(checkedInAt: now);

    final index = _reservations.indexWhere(
          (r) => r.id == reservationId,
    );

    _reservations[index] = updated;

    return updated;
  }

  @override
  Future<Reservation> cancelReservation(
      ReservationId reservationId,
      ) async {
    return updateReservationStatus(
      reservationId: reservationId,
      status: ReservationStatus.cancelled,
    );
  }
}
