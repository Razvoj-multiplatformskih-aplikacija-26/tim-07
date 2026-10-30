import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_fake_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/navigation/app_router.dart';

void main() {
  Future<void> openLocation(
    WidgetTester tester,
    MobileFakeReservationRepository repository,
    String location,
  ) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MyApp(repository: repository));
    AppRouter.router.go(location);
  }

  Future<void> openReservations(
    WidgetTester tester,
    MobileFakeReservationRepository repository,
  ) => openLocation(tester, repository, '/reservations');

  String reserveLocation({required String start, required String end}) {
    final tomorrow = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );

    return Uri(
      path: '/fields/1/reserve',
      queryParameters: {
        'date': tomorrow.toIso8601String(),
        'start': start,
        'end': end,
      },
    ).toString();
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

  testWidgets('Karticu rezervacije otvara poseban ekran detalja',
      (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openReservations(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('Detalji rezervacije'), findsOneWidget);
    expect(find.text('Termin'), findsOneWidget);
    expect(find.text('Cena'), findsOneWidget);
  });

  testWidgets('Detalj rezervacije otvara se direktno preko adrese',
      (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(tester, repository, '/reservations/11');
    await tester.pumpAndSettle();

    expect(find.text('Detalji rezervacije'), findsOneWidget);
    expect(find.text('Arena Fudbal'), findsOneWidget);
    expect(find.text('Potvrđena'), findsOneWidget);
  });

  testWidgets('Rezervacija drugog korisnika nije pronadjena', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(tester, repository, '/reservations/2');
    await tester.pumpAndSettle();

    expect(find.text('Rezervacija nije pronađena.'), findsOneWidget);
  });

  testWidgets('Detalj terena otvara se preko adrese sa identifikatorom',
      (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(tester, repository, '/fields/3');
    await tester.pumpAndSettle();

    expect(find.text('Detalji terena'), findsOneWidget);
    expect(find.text('Tennis Club'), findsOneWidget);
  });

  testWidgets('Nepoznat teren prikazuje poruku', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(tester, repository, '/fields/999');
    await tester.pumpAndSettle();

    expect(find.text('Teren nije pronađen.'), findsOneWidget);
  });

  testWidgets('Forma prijavljuje termin van radnog vremena', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(
      tester,
      repository,
      reserveLocation(start: '18:00', end: '19:00'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Termin je van radnog vremena terena.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(1), '23:30');
    await tester.pump();

    expect(find.text('Termin je van radnog vremena terena.'), findsOneWidget);
  });

  testWidgets('Forma trazi vreme u obliku HH:mm', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(
      tester,
      repository,
      reserveLocation(start: '18:00', end: '19:00'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'abc');
    await tester.pump();

    expect(
      find.text('Unesite vreme u obliku HH:mm, na primer 18:00.'),
      findsOneWidget,
    );
  });

  testWidgets('Ispravna forma pravi rezervaciju', (tester) async {
    final repository = createMobileRepository(delay: Duration.zero);
    await openLocation(
      tester,
      repository,
      reserveLocation(start: '12:00', end: '13:00'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Potvrdi rezervaciju'));
    await tester.pumpAndSettle();

    final mine = await repository.getReservationsByUser(
      MobileDemoData.currentUserId,
    );
    expect(mine.length, 11);
  });
}
