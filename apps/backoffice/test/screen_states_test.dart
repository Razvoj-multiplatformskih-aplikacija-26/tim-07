import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    BackofficeFakeReservationRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BackofficeApp(repository: repository));
  }

  Future<void> chooseSimulation(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('Ucitavanje prikazuje indikator, pa podatke', (tester) async {
    final repository = createBackofficeRepository(
      delay: const Duration(milliseconds: 300),
    );
    await pumpApp(tester, repository);
    await tester.pump();

    expect(find.text('Učitavanje rezervacija...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('Greska prikazuje poruku i Pokusaj ponovo ucitava podatke',
      (tester) async {
    final repository = createBackofficeRepository(delay: Duration.zero)
      ..failNextRequest();
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Rezervacije nisu učitane'), findsOneWidget);
    expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('Prazan odgovor prikazuje prazan ekran', (tester) async {
    final repository = createBackofficeRepository(delay: Duration.zero)
      ..returnEmptyOnNextRequest();
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Nema rezervacija'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.text('Osveži'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('Meni simulacije izaziva gresku sledeceg zahteva',
      (tester) async {
    final repository = createBackofficeRepository(delay: Duration.zero);
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await chooseSimulation(tester, 'Greška pri sledećem zahtevu');
    expect(repository.failsNextRequest, isTrue);

    await chooseSimulation(tester, 'Osveži rezervacije');

    expect(find.text('Rezervacije nisu učitane'), findsOneWidget);
  });

  testWidgets('Meni simulacije izaziva prazan odgovor', (tester) async {
    final repository = createBackofficeRepository(delay: Duration.zero);
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await chooseSimulation(tester, 'Prazan odgovor pri sledećem učitavanju');
    await chooseSimulation(tester, 'Osveži rezervacije');

    expect(find.text('Nema rezervacija'), findsOneWidget);
  });

  testWidgets('Ponovno ucitavanje zadrzava tabelu uz traku napretka',
      (tester) async {
    final repository = createBackofficeRepository(
      delay: const Duration(milliseconds: 300),
    );
    await pumpApp(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Osveži rezervacije'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
