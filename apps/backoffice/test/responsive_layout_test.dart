import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/widgets/reservation_details_panel.dart';
import 'package:backoffice/widgets/reservations_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wide = Size(1600, 1000);
  const narrow = Size(700, 1000);

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BackofficeApp(repository: createBackofficeRepository()),
    );
    await tester.pumpAndSettle();
  }

  bool rowSelected(WidgetTester tester, int id) {
    final table = tester.widget<DataTable>(find.byType(DataTable));
    return table.rows
        .firstWhere((row) => (row.key! as ValueKey<int>).value == id)
        .selected;
  }

  bool tileSelected(WidgetTester tester, int id) {
    final tile = tester.widget<ListTile>(find.byKey(ValueKey(id)));
    return tile.selected;
  }

  testWidgets('Sirok prozor prikazuje tabelu i bocni panel', (tester) async {
    await pumpApp(tester, wide);

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.byType(ReservationDetailsPanel), findsOneWidget);
    expect(find.byType(ReservationsList), findsNothing);
  });

  testWidgets('Uzak prozor prikazuje listu umesto tabele', (tester) async {
    await pumpApp(tester, narrow);

    expect(find.byType(ReservationsList), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(ReservationDetailsPanel), findsNothing);
  });

  testWidgets('U uskom prozoru izbor otvara detalje, a Nazad vraca listu',
      (tester) async {
    await pumpApp(tester, narrow);

    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();

    expect(find.text('Rezervacija #2'), findsOneWidget);
    expect(find.byType(ReservationsList), findsNothing);

    await tester.tap(find.text('Nazad na listu'));
    await tester.pumpAndSettle();

    expect(find.byType(ReservationsList), findsOneWidget);
    expect(tileSelected(tester, 2), isTrue);
  });

  testWidgets('Izbor se cuva pri suzavanju i sirenju prozora', (tester) async {
    await pumpApp(tester, wide);

    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();
    expect(rowSelected(tester, 2), isTrue);

    await resize(tester, narrow);
    expect(find.byType(ReservationsList), findsOneWidget);
    expect(tileSelected(tester, 2), isTrue);

    await resize(tester, wide);
    expect(rowSelected(tester, 2), isTrue);
    expect(find.text('Rezervacija #2'), findsOneWidget);
  });

  testWidgets('Tastatura radi i u uskom prozoru', (tester) async {
    await pumpApp(tester, narrow);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(tileSelected(tester, 6), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Rezervacija #6'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(ReservationsList), findsOneWidget);
    expect(tileSelected(tester, 6), isTrue);
  });
}
