import 'package:backoffice/selection/reservation_selection_bloc.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ReservationSelectionBloc bloc;

  setUp(() => bloc = ReservationSelectionBloc());

  tearDown(() => bloc.close());

  test('Pocetno stanje nema izabranu rezervaciju', () {
    expect(bloc.state, const ReservationSelectionState());
    expect(bloc.state.selectedId, isNull);
  });

  test('ReservationSelected postavlja izabranu rezervaciju', () async {
    bloc.add(const ReservationSelected(ReservationId(3)));

    await expectLater(
      bloc.stream,
      emits(const ReservationSelectionState(selectedId: ReservationId(3))),
    );
  });

  test('ReservationSelectionCleared uklanja izbor', () async {
    bloc
      ..add(const ReservationSelected(ReservationId(3)))
      ..add(const ReservationSelectionCleared());

    await expectLater(
      bloc.stream,
      emitsInOrder([
        const ReservationSelectionState(selectedId: ReservationId(3)),
        const ReservationSelectionState(),
      ]),
    );
  });

  test('Stanja su jednaka po vrednosti', () {
    expect(
      const ReservationSelectionState(selectedId: ReservationId(5)),
      const ReservationSelectionState(selectedId: ReservationId(5)),
    );
  });

  group('ReservationSelectionMoved', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    const order = [ReservationId(6), ReservationId(1), ReservationId(4)];

    Future<ReservationId?> move(int offset) async {
      bloc.add(ReservationSelectionMoved(offset: offset, order: order));
      await settle();
      return bloc.state.selectedId;
    }

    test('Bez izbora strelica dole bira prvi zapis', () async {
      expect(await move(1), const ReservationId(6));
    });

    test('Bez izbora strelica gore bira poslednji zapis', () async {
      expect(await move(-1), const ReservationId(4));
    });

    test('Pomera izbor za zadati broj mesta', () async {
      bloc.add(const ReservationSelected(ReservationId(6)));
      expect(await move(1), const ReservationId(1));
      expect(await move(1), const ReservationId(4));
    });

    test('Ne izlazi van granica liste', () async {
      bloc.add(const ReservationSelected(ReservationId(1)));
      expect(await move(10), const ReservationId(4));
      expect(await move(-10), const ReservationId(6));
    });

    test('Bez izbora skok na kraj bira poslednji, a na pocetak prvi zapis',
        () async {
      expect(await move(10), const ReservationId(4));
      bloc.add(const ReservationSelectionCleared());
      expect(await move(-10), const ReservationId(6));
    });

    test('Prazna lista ne menja izbor', () async {
      bloc.add(const ReservationSelected(ReservationId(1)));
      bloc.add(const ReservationSelectionMoved(offset: 1, order: []));
      await settle();
      expect(bloc.state.selectedId, const ReservationId(1));
    });
  });
}
