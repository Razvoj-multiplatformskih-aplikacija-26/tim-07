import 'package:backoffice/data/backoffice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  Future<void> openFields(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(backofficeApp(createBackofficeRepository(delay: Duration.zero)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tereni').first);
    await tester.pumpAndSettle();
  }

  testWidgets('stranica Tereni prikazuje terene vlasnika i radno vreme', (tester) async {
    await openFields(tester);

    expect(find.text('Dodaj teren'), findsOneWidget);
    expect(find.text('Radno vreme'), findsOneWidget);
    expect(find.text('Ponedeljak'), findsOneWidget);
  });

  testWidgets('forma ne prihvata prazan naziv i neispravan telefon', (tester) async {
    await openFields(tester);

    await tester.tap(find.text('Dodaj teren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Kontakt telefon'), 'abc');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Unesite naziv terena.'), findsOneWidget);
    expect(find.text('Unesite ispravan broj telefona.'), findsOneWidget);
  });

  testWidgets('novi teren se dodaje u listu', (tester) async {
    await openFields(tester);

    await tester.tap(find.text('Dodaj teren'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Naziv'), 'Novi padel');
    await tester.enterText(find.widgetWithText(TextField, 'Adresa'), 'Ulica 5');
    await tester.enterText(find.widgetWithText(TextField, 'Grad'), 'Niš');
    await tester.enterText(find.widgetWithText(TextField, 'Cena po satu (din)'), '2500');
    await tester.enterText(find.widgetWithText(TextField, 'Kontakt telefon'), '0641234567');
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(find.text('Novi padel'), findsWidgets);
    expect(find.textContaining('Čeka odobrenje'), findsWidgets);
  });
}
