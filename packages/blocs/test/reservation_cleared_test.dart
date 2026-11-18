import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Repozitorijum čiji odgovor stiže tek kada test to dozvoli, da se vidi šta
/// Bloc radi sa odgovorom koji kasni.
final class _SlowRepository implements ReservationRepository {
  final ReservationRepository _inner;
  final Completer<void> release = Completer<void>();

  _SlowRepository(this._inner);

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    await release.future;
    return _inner.getReservationsByUser(userId);
  }

  @override
  Future<List<Reservation>> getReservations() => _inner.getReservations();

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) =>
      _inner.getReservationsByField(fieldId);

  @override
  Future<Reservation?> getReservationById(ReservationId id) =>
      _inner.getReservationById(id);

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) => _inner.createReservation(
    fieldId: fieldId,
    userId: userId,
    startTime: startTime,
    endTime: endTime,
  );

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) => _inner.updateReservationStatus(
    reservationId: reservationId,
    status: status,
  );

  @override
  Future<Reservation> checkIn(ReservationId reservationId) =>
      _inner.checkIn(reservationId);

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) =>
      _inner.cancelReservation(reservationId);
}

void main() {
  late DateTime now;

  setUp(() => now = DateTime(2026, 10, 17, 12));

  FakeReservationRepository fake() => FakeReservationRepository(
    fields: DemoData.fields,
    schedules: DemoData.schedules,
    reservations: DemoData.createReservations(now: now),
    blockedPeriods: DemoData.blockedPeriods,
    clock: () => now,
  );

  test('brisanje vraća početno stanje, bez rezervacija prethodnog korisnika', () async {
    final bloc = ReservationBloc(repository: fake());
    bloc.add(const ReservationsRequested());
    await bloc.stream.firstWhere((s) => s is ReservationLoaded);

    bloc.add(const ReservationsCleared());
    await bloc.stream.firstWhere((s) => s is ReservationInitial);

    expect(bloc.state, const ReservationInitial());
    await bloc.close();
  });

  test('odgovor koji stigne posle brisanja se odbacuje', () async {
    final repository = _SlowRepository(fake());
    final bloc = ReservationBloc(repository: repository);
    final states = <ReservationState>[];
    final subscription = bloc.stream.listen(states.add);

    bloc.add(const UserReservationsRequested(UserId(1)));
    await pumpEventQueue();
    expect(bloc.state, const ReservationLoading());

    // Korisnik se odjavio dok je upit još trajao.
    bloc.add(const ReservationsCleared());
    await pumpEventQueue();
    repository.release.complete();
    await pumpEventQueue();

    expect(bloc.state, const ReservationInitial());
    expect(states.whereType<ReservationLoaded>(), isEmpty);

    await subscription.cancel();
    await bloc.close();
  });

  test('posle brisanja novo učitavanje radi normalno', () async {
    final bloc = ReservationBloc(repository: fake());
    bloc.add(const ReservationsCleared());
    await pumpEventQueue();

    bloc.add(const ReservationsRequested());
    final loaded = await bloc.stream.firstWhere((s) => s is ReservationLoaded);

    expect(loaded, isA<ReservationLoaded>());
    await bloc.close();
  });
}
