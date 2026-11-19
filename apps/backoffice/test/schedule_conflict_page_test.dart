import 'package:backoffice/data/backoffice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  // Demo rezervacija 1: Arena Fudbal, sutra od 18 do 20 časova, potvrđena.
  final tomorrowIndex = DateTime.now().add(const Duration(days: 1)).weekday - 1;

  Future<void> openFields(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      backofficeApp(createBackofficeRepository(delay: Duration.zero)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tereni').first);
    await tester.pumpAndSettle();
  }

  /// Padajuće liste vremena u redosledu: otvaranje i zatvaranje za svaki dan.
  Finder times() => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('DropdownButton<'),
  );

  Future<void> setClosing(WidgetTester tester, String time) async {
    final closing = times().at(tomorrowIndex * 2 + 1);
    await tester.ensureVisible(closing);
    await tester.tap(closing);
    await tester.pumpAndSettle();
    await tester.tap(find.text(time).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'skraćenje radnog vremena preko potvrđene rezervacije: poruka sa razlogom',
    (tester) async {
      await openFields(tester);

      // Rezervacija sutra je do 20 časova; zatvaranje u 19 je ne obuhvata.
      await setClosing(tester, '19:00');
      await tester.ensureVisible(find.text('Sačuvaj radno vreme'));
      await tester.tap(find.text('Sačuvaj radno vreme'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Radno vreme nije sačuvano'), findsWidgets);
      expect(find.textContaining('jednu postojeću rezervaciju'), findsWidgets);
      expect(find.text('Radno vreme je sačuvano.'), findsNothing);
    },
  );

  testWidgets('promena koja obuhvata rezervaciju se čuva', (tester) async {
    await openFields(tester);

    await setClosing(tester, '22:00');
    await tester.ensureVisible(find.text('Sačuvaj radno vreme'));
    await tester.tap(find.text('Sačuvaj radno vreme'));
    await tester.pumpAndSettle();

    expect(find.text('Radno vreme je sačuvano.'), findsWidgets);
  });
}
