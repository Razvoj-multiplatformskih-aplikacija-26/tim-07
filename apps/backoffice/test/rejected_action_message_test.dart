import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Izvor koji odbija izmenu stanja rezervacije, kao server koji kaže „ne“
/// (nemate pravo, stanje se u međuvremenu promenilo, rok je istekao).
final class _RejectingRepository extends BackofficeFakeReservationRepository {
  _RejectingRepository(super.store, this._error) : super(delay: Duration.zero);

  final Object _error;

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async => throw _error;

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async =>
      throw _error;
}

void main() {
  Future<void> pumpApp(WidgetTester tester, Object error) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = createBackofficeRepository(delay: Duration.zero).store;
    await tester.pumpWidget(backofficeApp(_RejectingRepository(store, error)));
    await tester.pumpAndSettle();
  }

  Future<void> selectRow(WidgetTester tester, int id) async {
    await tester.tap(find.text('#$id'));
    await tester.pumpAndSettle();
  }

  testWidgets('Odbijena potvrda pokazuje razlog umesto tišine', (tester) async {
    await pumpApp(
      tester,
      const ReservationRuleViolation(InvalidReservationStatus()),
    );
    await selectRow(tester, 2);

    await tester.tap(find.widgetWithText(FilledButton, 'Potvrdi'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Trenutni status rezervacije ne dozvoljava ovu radnju.'),
      findsOneWidget,
    );
  });

  testWidgets('Odbijeno otkazivanje pokazuje razlog i tabela ostaje', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const ReservationRuleViolation(CancellationDeadlineExpired()),
    );
    await selectRow(tester, 4);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Odbij'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Odbij'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('nije moguće otkazati'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
  });
}
