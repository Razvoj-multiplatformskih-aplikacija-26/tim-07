
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

  group('ReservationBloc - ucitavanje', () {
    test('pocetno stanje je ReservationInitial', () async {
      final bloc = ReservationBloc(repository: repository);

      expect(bloc.state, isA<ReservationInitial>());

      await bloc.close();
    });

    test('ucitava sve rezervacije', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

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

    test('ucitava rezervacije jednog korisnika', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(UserReservationsRequested(UserId(1)));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>().having(
                (state) => state.reservations.length,
            'broj rezervacija korisnika',
            2,
          ),
        ]),
      );

      await bloc.close();
    });

    test('ucitava rezervacije jednog terena', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(FieldReservationsRequested(FieldId(2)));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>().having(
                (state) => state.reservations.length,
            'broj rezervacija terena',
            1,
          ),
        ]),
      );

      await bloc.close();
    });

    test('vraca Empty za korisnika bez rezervacija', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(UserReservationsRequested(UserId(999)));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationEmpty>(),
        ]),
      );

      await bloc.close();
    });
  });

  group('ReservationBloc - akcije', () {
    test('kreira rezervaciju i osvezava listu', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(
        ReservationCreateRequested(
          fieldId: FieldId(1),
          userId: UserId(3),
          startTime: DateTime(2026, 10, 22, 10),
          endTime: DateTime(2026, 10, 22, 12),
        ),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>().having(
                (state) => state.reservations.length,
            'broj rezervacija posle kreiranja',
            4,
          ),
        ]),
      );

      await bloc.close();
    });

    test('otkazuje rezervaciju', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(
        ReservationCancelRequested(ReservationId(2)),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>().having(
                (state) => state.reservations.any(
                  (reservation) =>
              reservation.id == ReservationId(2) &&
                  reservation.status == ReservationStatus.cancelled,
            ),
            'rezervacija je otkazana',
            true,
          ),
        ]),
      );

      await bloc.close();
    });

    test('vraca Error kada kreiranje nije dozvoljeno', () async {
      final bloc = ReservationBloc(repository: repository);

      bloc.add(
        ReservationCreateRequested(
          fieldId: FieldId(1),
          userId: UserId(3),
          startTime: DateTime(2026, 10, 18, 19),
          endTime: DateTime(2026, 10, 18, 21),
        ),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationError>(),
        ]),
      );

      await bloc.close();
    });
  });

  group('ReservationBloc - zamena repository implementacije', () {
    test('radi sa praznim FakeRepository', () async {
      final emptyRepository = FakeReservationRepository(
        clock: () => now,
      );

      final bloc = ReservationBloc(
        repository: emptyRepository,
      );

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

    test('radi sa repository koji simulira gresku', () async {
      repository.simulateError = true;

      final bloc = ReservationBloc(
        repository: repository,
      );

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
  });
}
