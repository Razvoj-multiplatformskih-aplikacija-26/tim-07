import 'package:backoffice/data/backoffice_repository.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());

  int rows(WidgetTester tester) =>
      tester.widget<DataTable>(find.byType(DataTable)).rows.length;

  Future<void> pumpApp(WidgetTester tester, dynamic repository) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(backofficeApp(repository));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'rezervacija iz drugog klijenta se pojavi sama, posle 30 sekundi',
    (tester) async {
      final repository = createBackofficeRepository(delay: Duration.zero);
      await pumpApp(tester, repository);
      expect(rows(tester), 7);

      // Mobilna aplikacija je u međuvremenu napravila rezervaciju.
      await repository.createReservation(
        fieldId: const FieldId(1),
        userId: const UserId(2),
        startTime: today.add(const Duration(days: 7, hours: 12)),
        endTime: today.add(const Duration(days: 7, hours: 13)),
      );
      await tester.pump(const Duration(seconds: 20));
      expect(rows(tester), 7, reason: 'još nije prošlo 30 sekundi');

      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();

      expect(rows(tester), 8);
    },
  );

  testWidgets('posle greške lista se sama oporavi čim server proradi', (
    tester,
  ) async {
    final repository = createBackofficeRepository(delay: Duration.zero)
      ..failNextRequest();
    await pumpApp(tester, repository);
    expect(find.text('Rezervacije nisu učitane'), findsOneWidget);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Rezervacije nisu učitane'), findsNothing);
    expect(rows(tester), 7);
  });

  testWidgets('filteri i izbor ostaju posle osvežavanja u pozadini', (
    tester,
  ) async {
    final repository = createBackofficeRepository(delay: Duration.zero);
    await pumpApp(tester, repository);
    await tester.tap(find.text('#4'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Rezervacija #4'), findsOneWidget);
    expect(rows(tester), 7);
  });
}
