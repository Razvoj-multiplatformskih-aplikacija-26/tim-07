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
}
