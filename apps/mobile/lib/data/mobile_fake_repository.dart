import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

class MobileFakeReservationRepository implements ReservationRepository {
  final FakeReservationRepository _store;
  final Duration delay;

  bool _failNext = false;
  bool _emptyNext = false;

  MobileFakeReservationRepository(
    this._store, {
    this.delay = const Duration(milliseconds: 600),
  });

  bool get failsNextRequest => _failNext;

  bool get returnsEmptyOnNextRequest => _emptyNext;

  void failNextRequest() => _failNext = true;

  void returnEmptyOnNextRequest() => _emptyNext = true;

  Future<void> _simulateNetwork() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (_failNext) {
      _failNext = false;
      throw StateError('Server trenutno nije dostupan.');
    }
  }

  @override
  Future<List<Reservation>> getReservations() async {
    await _simulateNetwork();

    if (_emptyNext) {
      _emptyNext = false;
      return const [];
    }

    return _store.getReservations();
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    await _simulateNetwork();

    if (_emptyNext) {
      _emptyNext = false;
      return const [];
    }

    return _store.getReservationsByUser(userId);
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    await _simulateNetwork();
    return _store.getReservationsByField(fieldId);
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    await _simulateNetwork();
    return _store.getReservationById(id);
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await _simulateNetwork();
    return _store.createReservation(
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    await _simulateNetwork();
    return _store.updateReservationStatus(
      reservationId: reservationId,
      status: status,
    );
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    await _simulateNetwork();
    return _store.checkIn(reservationId);
  }

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async {
    await _simulateNetwork();
    return _store.cancelReservation(reservationId);
  }
}
