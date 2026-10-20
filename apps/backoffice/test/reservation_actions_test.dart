import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeReservationRepository repository;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repository = createBackofficeRepository();

    await tester.pumpWidget(BackofficeApp(repository: repository));
    await tester.pumpAndSettle();
  }

  Future<void> selectRow(WidgetTester tester, int id) async {
    await tester.tap(find.text('#$id'));
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) => find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(text),
      );

  Future<ReservationStatus?> statusOf(int id) async =>
      (await repository.getReservationById(ReservationId(id)))?.status;

  testWidgets('Potvrdi menja status rezervacije na cekanju', (tester) async {
    await pumpApp(tester);
    await selectRow(tester, 2);

    await tester.tap(find.widgetWithText(FilledButton, 'Potvrdi'));
    await tester.pumpAndSettle();

    expect(await statusOf(2), ReservationStatus.confirmed);
    expect(find.text('Rezervacija #2'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Otkaži'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Potvrdi'), findsNothing);
  });

  testWidgets('Odbij trazi potvrdu i otkazuje rezervaciju', (tester) async {
    await pumpApp(tester);
    await selectRow(tester, 4);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Odbij'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(inDialog('Odbij rezervaciju #4?'), findsOneWidget);

    await tester.tap(inDialog('Odbij'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(await statusOf(4), ReservationStatus.cancelled);
    expect(find.text('Nema dostupnih akcija za ovaj status.'), findsOneWidget);
  });

  testWidgets('Odustani u dijalogu ne menja rezervaciju', (tester) async {
    await pumpApp(tester);
    await selectRow(tester, 4);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Odbij'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Odustani'));
    await tester.pumpAndSettle();

    expect(await statusOf(4), ReservationStatus.pending);
    expect(find.widgetWithText(FilledButton, 'Potvrdi'), findsOneWidget);
  });
}
