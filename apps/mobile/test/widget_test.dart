import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_fake_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/navigation/app_router.dart';

void main() {
  Future<void> openReservations(
    WidgetTester tester,
    MobileFakeReservationRepository repository,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MyApp(repository: repository));
    AppRouter.router.go('/reservations');
  }

  test('Demo podaci imaju bar deset rezervacija korisnika u svim stanjima',
      () {
    final mine = MobileDemoData.createReservations()
        .where((r) => r.userId == MobileDemoData.currentUserId)
        .toList();

    expect(mine.length, greaterThanOrEqualTo(10));
    expect(
      mine.map((r) => r.status).toSet(),
      ReservationStatus.values.toSet(),
    );
  });

  testWidgets('Ucitavanje prikazuje indikator, pa rezervacije',
      (tester) async {
    final repository = createMobileRepository(
      delay: const Duration(milliseconds: 300),
    );
    await openReservations(tester, repository);
    await tester.pump();
    await tester.pump();

    expect(find.text('Učitavanje rezervacija...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Moje rezervacije'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Greska prikazuje Pokusaj ponovo', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero)
      ..failNextRequest();
    await openReservations(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Rezervacije nisu učitane'), findsOneWidget);
    expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);

    await tester.tap(find.text('Pokušaj ponovo'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Prazan odgovor prikazuje prazan ekran', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero)
      ..returnEmptyOnNextRequest();
    await openReservations(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Nemate rezervacija'), findsOneWidget);

    await tester.tap(find.text('Osveži'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Meni simulacije izaziva gresku sledeceg zahteva',
      (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openReservations(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greška pri sledećem zahtevu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Simulacija'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Osveži rezervacije'));
    await tester.pumpAndSettle();

    expect(find.text('Rezervacije nisu učitane'), findsOneWidget);
  });

  testWidgets('Otkazivanje trazi potvrdu i menja status preko Bloc-a',
      (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openReservations(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Otkaži rezervaciju').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Da, otkaži'));
    await tester.pumpAndSettle();

    final reservation =
        await repository.getReservationById(const ReservationId(15));
    expect(reservation?.status, ReservationStatus.cancelled);
  });
}
