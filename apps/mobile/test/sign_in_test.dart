import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_auth.dart';
import 'package:mobile/data/mobile_availability_repository.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_field_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/data/mobile_schedule_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/navigation/app_router.dart';

const _expiredMessage = 'Prijava je istekla. Prijavite se ponovo.';

final _marko = MobileDemoData.accounts[0].user;
final _jelena = MobileDemoData.accounts[1].user;
final _owner = MobileDemoData.accounts[2].user;

void main() {
  /// Pokreće aplikaciju na [location]; [signedInAs] glumi sačuvanu prijavu.
  Future<FakeAuthRepository> pumpApp(
    WidgetTester tester, {
    String location = '/',
    AppUser? signedInAs,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final auth = createMobileAuthRepository(delay: Duration.zero);
    if (signedInAs != null) {
      await auth.logIn(
        email: signedInAs.email,
        password: MobileDemoData.demoPassword,
      );
    }

    final reservations = createMobileRepository(delay: Duration.zero);

    await tester.pumpWidget(
      MyApp(
        repository: reservations,
        availabilityRepository: createMobileAvailabilityRepository(
          reservations: reservations,
          delay: Duration.zero,
        ),
        fieldRepository: createMobileFieldRepository(delay: Duration.zero),
        scheduleRepository: createMobileScheduleRepository(),
        authRepository: auth,
        initialLocation: location,
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> signIn(
    WidgetTester tester,
    String email, [
    String password = MobileDemoData.demoPassword,
  ]) async {
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();
  }

  final loginForm = find.text('Prijavite se da biste rezervisali teren');

  group('katalog je javan, rezervacije traže prijavu', () {
    testWidgets('tereni se vide bez prijave', (tester) async {
      await pumpApp(tester, location: '/fields');

      expect(find.text('Sportski tereni'), findsOneWidget);
      expect(loginForm, findsNothing);
      expect(find.byTooltip('Prijavi se'), findsOneWidget);
    });

    testWidgets('detalj terena se vidi bez prijave', (tester) async {
      await pumpApp(tester, location: '/fields/3');

      expect(find.text('Detalji terena'), findsOneWidget);
      expect(find.text('Tennis Club'), findsOneWidget);
    });

    testWidgets('moje rezervacije bez prijave vode na prijavu', (tester) async {
      await pumpApp(tester, location: '/reservations');

      expect(loginForm, findsOneWidget);
      expect(find.text('Moje rezervacije'), findsNothing);
    });

    testWidgets('forma za rezervaciju bez prijave vodi na prijavu', (
      tester,
    ) async {
      await pumpApp(
        tester,
        location: '/fields/1/reserve?date=2026-12-01&start=18:00&end=19:00',
      );

      expect(loginForm, findsOneWidget);
      expect(find.text('Nova rezervacija'), findsNothing);
    });

    testWidgets('posle prijave korisnik se vraća na ekran na koji je išao', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations');

      await signIn(tester, _marko.email);

      expect(find.text('Moje rezervacije'), findsOneWidget);
      expect(loginForm, findsNothing);
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('prijavljen korisnik vidi svoje ime iz AuthBloc-a', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations', signedInAs: _marko);

      expect(find.text(_marko.fullName), findsWidgets);
      expect(find.text(_jelena.fullName), findsNothing);
    });

    testWidgets('dugme „Nastavi bez prijave“ vodi na početnu', (tester) async {
      await pumpApp(tester, location: '/reservations');

      await tester.tap(find.text('Nastavi bez prijave'));
      await tester.pumpAndSettle();

      expect(loginForm, findsNothing);
      expect(find.text('Dobrodošli!'), findsOneWidget);
    });
  });

  group('prijava', () {
    testWidgets('pogrešna lozinka kaže razlog i ostaje na prijavi', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations');

      await signIn(tester, _marko.email, 'pogresna');

      expect(find.text('Pogrešan e-mail ili lozinka.'), findsOneWidget);
      expect(loginForm, findsOneWidget);
    });

    testWidgets('nepostojeći e-mail daje istu poruku', (tester) async {
      await pumpApp(tester, location: '/reservations');

      await signIn(tester, 'niko@example.com');

      expect(find.text('Pogrešan e-mail ili lozinka.'), findsOneWidget);
    });

    testWidgets('prazna polja ne šalju zahtev', (tester) async {
      await pumpApp(tester, location: '/reservations');

      await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
      await tester.pumpAndSettle();

      expect(find.text('Unesite e-mail i lozinku.'), findsOneWidget);
    });

    testWidgets('vlasnik se ne prijavljuje u mobilnu aplikaciju', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations');

      await signIn(tester, _owner.email);

      expect(
        find.text(
          'Ova aplikacija je za korisnike. Osoblje se prijavljuje u backoffice.',
        ),
        findsOneWidget,
      );
      expect(find.text('Moje rezervacije'), findsNothing);
    });

    testWidgets('poruka greške nije tehnički tekst', (tester) async {
      await pumpApp(tester, location: '/reservations');

      await signIn(tester, _marko.email, 'pogresna');

      expect(find.textContaining('invalid_credentials'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('lozinka je skrivena, a dugme je prikazuje', (tester) async {
      await pumpApp(tester, location: '/reservations');

      TextField password() =>
          tester.widget<TextField>(find.byType(TextField).at(1));
      expect(password().obscureText, isTrue);

      await tester.tap(find.byTooltip('Prikaži lozinku'));
      await tester.pump();

      expect(password().obscureText, isFalse);
    });
  });

  group('odjava', () {
    testWidgets('odjava vraća na početnu i zatvara rezervacije', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations', signedInAs: _marko);
      expect(find.text('Moje rezervacije'), findsOneWidget);

      await tester.tap(find.byTooltip('Nalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odjavi se'));
      await tester.pumpAndSettle();

      expect(find.text('Dobrodošli!'), findsOneWidget);
      expect(find.byTooltip('Prijavi se'), findsOneWidget);

      // Rezervacije više nisu dostupne bez nove prijave.
      await tester.tap(find.text('Rezervacije'));
      await tester.pumpAndSettle();
      expect(loginForm, findsOneWidget);
    });

    testWidgets('odjava briše sačuvanu prijavu', (tester) async {
      final auth = await pumpApp(
        tester,
        location: '/reservations',
        signedInAs: _marko,
      );
      expect(auth.stored, isNotNull);

      await tester.tap(find.byTooltip('Nalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odjavi se'));
      await tester.pumpAndSettle();

      expect(auth.stored, isNull);
    });

    testWidgets('drugi korisnik posle odjave ne vidi tuđe rezervacije', (
      tester,
    ) async {
      await pumpApp(tester, location: '/reservations', signedInAs: _marko);

      await tester.tap(find.byTooltip('Nalog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odjavi se'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rezervacije'));
      await tester.pumpAndSettle();
      await signIn(tester, _jelena.email);

      expect(find.text(_jelena.fullName), findsWidgets);
      expect(find.text(_marko.fullName), findsNothing);
    });

    testWidgets('tuđa rezervacija se ne otvara ni direktnom adresom', (
      tester,
    ) async {
      // Rezervacija 1 pripada Marku.
      await pumpApp(tester, location: '/reservations/1', signedInAs: _jelena);

      expect(find.text('Rezervacija nije pronađena.'), findsOneWidget);
    });
  });

  group('istek prijave', () {
    testWidgets('na zaštićenom ekranu vraća na prijavu uz poruku', (
      tester,
    ) async {
      final auth = await pumpApp(
        tester,
        location: '/reservations',
        signedInAs: _marko,
      );
      expect(find.text('Moje rezervacije'), findsOneWidget);

      auth.expire();
      await tester.pumpAndSettle();

      expect(loginForm, findsOneWidget);
      expect(find.text(_expiredMessage), findsOneWidget);
    });

    testWidgets('posle nove prijave vraća na isti ekran', (tester) async {
      final auth = await pumpApp(
        tester,
        location: '/reservations/11',
        signedInAs: _marko,
      );
      expect(find.text('Detalji rezervacije'), findsOneWidget);

      auth.expire();
      await tester.pumpAndSettle();
      await signIn(tester, _marko.email);

      expect(find.text('Detalji rezervacije'), findsOneWidget);
      expect(find.text(_expiredMessage), findsNothing);
    });

    testWidgets('na javnom ekranu ostaje gde je, uz obaveštenje', (
      tester,
    ) async {
      final auth = await pumpApp(
        tester,
        location: '/fields',
        signedInAs: _marko,
      );
      expect(find.byTooltip('Nalog'), findsOneWidget);

      auth.expire();
      await tester.pumpAndSettle();

      expect(find.text('Sportski tereni'), findsOneWidget);
      expect(find.text(_expiredMessage), findsOneWidget);
      expect(find.byTooltip('Prijavi se'), findsOneWidget);
    });
  });

  group('zaštita ruta (AppRouter.guard)', () {
    const signedOut = AuthUnauthenticated();
    final signedIn = AuthAuthenticated(
      user: _marko,
      expiresAt: DateTime.utc(2030),
    );

    test('javne adrese ne traže prijavu', () {
      for (final path in ['/', '/fields', '/fields/3']) {
        expect(
          AppRouter.guard(signedOut, Uri.parse(path)),
          isNull,
          reason: path,
        );
      }
    });

    test('rezervisanje i moje rezervacije traže prijavu', () {
      for (final path in [
        '/reservations',
        '/reservations/7',
        '/fields/3/reserve?date=2026-12-01&start=18:00&end=19:00',
      ]) {
        final target = AppRouter.guard(signedOut, Uri.parse(path));

        expect(target, startsWith('/login?from='), reason: path);
        expect(Uri.parse(target!).queryParameters['from'], path);
      }
    });

    test('dok se prijava proverava, zaštićena adresa čeka na prijavi', () {
      expect(
        AppRouter.guard(const AuthUnknown(), Uri.parse('/reservations')),
        startsWith('/login'),
      );
    });

    test('prijavljen korisnik ide na zaštićenu adresu', () {
      expect(AppRouter.guard(signedIn, Uri.parse('/reservations')), isNull);
    });

    test('prijavljen korisnik sa prijave ide tamo odakle je došao', () {
      expect(
        AppRouter.guard(signedIn, Uri.parse('/login?from=%2Freservations%2F7')),
        '/reservations/7',
      );
      expect(AppRouter.guard(signedIn, Uri.parse('/login')), '/');
    });

    test('adresa za povratak ne sme da vodi van aplikacije ni u petlju', () {
      for (final from in [
        '//evil.example.com',
        'https://evil.example.com',
        '/login',
        '/login?from=%2F',
      ]) {
        final uri = Uri(path: '/login', queryParameters: {'from': from});

        expect(AppRouter.guard(signedIn, uri), '/', reason: from);
      }
    });

    test('neprijavljen korisnik ostaje na prijavi', () {
      expect(AppRouter.guard(signedOut, Uri.parse('/login?from=%2F')), isNull);
    });
  });
}
