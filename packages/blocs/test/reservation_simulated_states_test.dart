
import 'package:blocs/blocs.dart';
import 'package:test/test.dart';

void main() {
  group('ReservationBloc - simulirana stanja', () {
    test('vraca Empty kada repository simulira praznu listu', () async {
      final repository = FakeReservationRepository(
        reservations: DemoData.createReservations(),
      );

      repository.simulateEmpty = true;

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationEmpty>(),
        ]),
      );

      await bloc.close();
    });

    test('vraca Error kada repository simulira gresku', () async {
      final repository = FakeReservationRepository(
        reservations: DemoData.createReservations(),
      );

      repository.simulateError = true;

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationError>(),
        ]),
      );

      await bloc.close();
    });

    test('vraca Loaded kada postoje rezervacije', () async {
      final repository = FakeReservationRepository(
        reservations: DemoData.createReservations(),
      );

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>(),
        ]),
      );

      await bloc.close();
    });
  });
}
