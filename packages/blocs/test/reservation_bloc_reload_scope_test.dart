import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late FakeReservationRepository repository;

  setUp(() {
    now = DateTime(2026, 10, 17, 12);

    repository = FakeReservationRepository(
      fields: DemoData.fields,
      schedules: DemoData.schedules,
      reservations: DemoData.createReservations(now: now),
      blockedPeriods: DemoData.blockedPeriods,
      clock: () => now,
    );
  });

  test('posle akcije ponovo ucitava samo rezervacije istog korisnika', () async {
    final bloc = ReservationBloc(repository: repository);

    bloc.add(const UserReservationsRequested(UserId(1)));
    await expectLater(
      bloc.stream,
      emitsInOrder([isA<ReservationLoading>(), isA<ReservationLoaded>()]),
    );

    bloc.add(const ReservationCancelRequested(ReservationId(1)));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ReservationLoading>(),
        isA<ReservationLoaded>()
            .having(
              (state) => state.reservations.every(
                (reservation) => reservation.userId == const UserId(1),
              ),
              'samo korisnik 1',
              isTrue,
            )
            .having(
              (state) => state.reservations
                  .firstWhere((r) => r.id == const ReservationId(1))
                  .status,
              'status rezervacije 1',
              ReservationStatus.cancelled,
            ),
      ]),
    );

    await bloc.close();
  });

  test('bez prethodnog ucitavanja akcija ucitava sve rezervacije', () async {
    final bloc = ReservationBloc(repository: repository);

    bloc.add(const ReservationCancelRequested(ReservationId(1)));

    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<ReservationLoading>(),
        isA<ReservationLoaded>().having(
          (state) => state.reservations.length,
          'broj rezervacija',
          3,
        ),
      ]),
    );

    await bloc.close();
  });
}
