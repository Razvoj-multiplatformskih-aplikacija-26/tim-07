import 'package:blocs/blocs.dart';
import 'package:test/test.dart';

// Fiksiran trenutak: ni demo rezervacije ni stanja koja iz njih proizlaze ne
// zavise od sata na kome se testovi pokreću.
final now = DateTime(2026, 11, 1, 9);

FakeReservationRepository repositoryWithDemoData() => FakeReservationRepository(
  reservations: DemoData.createReservations(now: now),
  clock: () => now,
);

void main() {
  group('ReservationBloc - simulirana stanja', () {
    test('vraca Empty kada repository simulira praznu listu', () async {
      final repository = repositoryWithDemoData();

      repository.simulateEmpty = true;

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<ReservationLoading>(), isA<ReservationEmpty>()]),
      );

      await bloc.close();
    });

    test('vraca Error kada repository simulira gresku', () async {
      final repository = repositoryWithDemoData();

      repository.simulateError = true;

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<ReservationLoading>(), isA<ReservationError>()]),
      );

      await bloc.close();
    });

    test('vraca Loaded kada postoje rezervacije', () async {
      final repository = repositoryWithDemoData();

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([isA<ReservationLoading>(), isA<ReservationLoaded>()]),
      );

      await bloc.close();
    });
  });
}
