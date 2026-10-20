import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Backoffice prikazuje navigaciju i tabelu rezervacija',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BackofficeApp(repository: createBackofficeRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Tereni'), findsOneWidget);

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
      table.rows.length,
      BackofficeDemoData.createReservations().length,
    );
  });

  testWidgets('Navigacija menja izabranu sekciju', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BackofficeApp(repository: createBackofficeRepository()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistika'));
    await tester.pumpAndSettle();

    expect(
      find.text('Statistika zauzetosti biće dodata u narednim taskovima.'),
      findsOneWidget,
    );
  });
}
