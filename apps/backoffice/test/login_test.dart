import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(int id, UserRole role, String email) => AppUser(
  id: UserId(id),
  firstName: 'Ime',
  lastName: role.name,
  email: email,
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026),
);

void main() {
  late FakeAuthRepository auth;

  setUp(() {
    auth = FakeAuthRepository(
      accounts: [
        FakeAccount(user: _user(10, UserRole.owner, 'vlasnik@terenzo.rs'), password: 'lozinka'),
        FakeAccount(user: _user(1, UserRole.user, 'korisnik@terenzo.rs'), password: 'lozinka'),
      ],
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final reservations = createBackofficeRepository(delay: Duration.zero);
    await tester.pumpWidget(
      BackofficeApp(
        repository: reservations,
        fieldRepository: createBackofficeFieldRepository(),
        scheduleRepository: createBackofficeScheduleRepository(reservations: reservations),
        authRepository: auth,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email) async {
    await tester.enterText(find.widgetWithText(TextField, 'E-mail'), email);
    await tester.enterText(find.widgetWithText(TextField, 'Lozinka'), 'lozinka');
    await tester.tap(find.widgetWithText(FilledButton, 'Prijavi se'));
    await tester.pumpAndSettle();
  }

  testWidgets('posle prijave imena korisnika ne dolaze iz demo podataka', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'vlasnik@terenzo.rs');

    // Rezervacija 1 pripada korisniku 1. Demo korisnik 1 je „Jovan Petrović“, ali
    // nad serverom korisnik 1 može biti bilo ko, pa se tuđe ime ne izmišlja.
    expect(find.text('Jovan Petrović'), findsNothing);
    expect(find.text('Korisnik #1'), findsWidgets);
    // Tereni se čitaju iz izvora podataka, pa imaju prava imena.
    expect(find.text('Arena Fudbal'), findsWidgets);
  });

  testWidgets('bez prijave backoffice prikazuje ekran prijave', (tester) async {
    await pumpApp(tester);

    expect(find.text('Terenzo backoffice'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('vlasnik se prijavljuje i vidi rezervacije, odjava vraća na prijavu', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'vlasnik@terenzo.rs');
    expect(find.byType(DataTable), findsOneWidget);

    await tester.tap(find.byTooltip('Odjavi se'));
    await tester.pumpAndSettle();
    expect(find.text('Terenzo backoffice'), findsOneWidget);
    expect(auth.stored, isNull);
  });

  testWidgets('korisnik mobilne aplikacije biva odbijen uz razlog', (tester) async {
    await pumpApp(tester);

    await signIn(tester, 'korisnik@terenzo.rs');

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Backoffice je za vlasnike i administratore sportskih objekata.'), findsOneWidget);
  });

  testWidgets('istekla prijava vraća na prijavu uz poruku', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'vlasnik@terenzo.rs');

    auth.expire();
    await tester.pumpAndSettle();

    expect(find.text('Terenzo backoffice'), findsOneWidget);
    expect(find.textContaining('istek'), findsOneWidget);
  });
}
