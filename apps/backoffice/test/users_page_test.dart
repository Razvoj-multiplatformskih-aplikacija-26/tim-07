import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/screens/users_page.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/messages.dart';

final admin = AppUser(
  id: const UserId(99),
  firstName: 'Mina',
  lastName: 'Admin',
  email: 'mina.admin@example.com',
  phoneNumber: '0600000000',
  dateOfBirth: DateTime(1988, 4, 4),
  role: UserRole.admin,
  createdAt: DateTime(2025, 1, 1),
);

/// Izvor naloga koji ne može da se učita ili ne može da menja.
final class _Source implements UserAdministrationRepository {
  final UserAdministrationRepository inner;
  Object? readError;
  Object? writeError;

  _Source(this.inner);

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    final failure = readError;
    if (failure != null) throw failure;
    return inner.getUsers(role: role);
  }

  @override
  Future<AppUser> setUserActive(UserId id, {required bool active}) async {
    final failure = writeError;
    if (failure != null) throw failure;
    return inner.setUserActive(id, active: active);
  }
}

void main() {
  late _Source source;

  Future<void> pumpApp(
    WidgetTester tester, {
    AppUser? viewer,
    Size size = const Size(1600, 1000),
    bool openUsers = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    source = _Source(
      FakeUserAdministrationRepository(
        users: [...BackofficeDemoData.users, BackofficeDemoData.owner, admin],
      ),
    );
    final reservations = createBackofficeRepository(delay: Duration.zero);

    await tester.pumpWidget(
      BackofficeApp(
        repository: reservations,
        fieldRepository: createBackofficeFieldRepository(),
        scheduleRepository: createBackofficeScheduleRepository(
          reservations: reservations,
        ),
        userRepository: source,
        owner: viewer ?? admin,
      ),
    );
    await tester.pumpAndSettle();

    if (openUsers) {
      await tester.tap(find.text('Korisnici'));
      await tester.pumpAndSettle();
    }
  }

  /// Imena u tabeli, odozgo nadole.
  List<String> names(WidgetTester tester) => [
    for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
      (((row.cells.first.child as Column).children.first as Text).data!),
  ];

  group('pristup', () {
    testWidgets('administrator ima stavku „Korisnici“', (tester) async {
      await pumpApp(tester, openUsers: false);

      expect(find.text('Korisnici'), findsOneWidget);
    });

    testWidgets('vlasnik nema stavku „Korisnici“', (tester) async {
      await pumpApp(tester, viewer: BackofficeDemoData.owner, openUsers: false);

      expect(find.text('Korisnici'), findsNothing);
      expect(find.byType(UsersPage), findsNothing);
    });
  });

  group('spisak', () {
    testWidgets('svi nalozi sa ulogom, datumom registracije i stanjem', (
      tester,
    ) async {
      await pumpApp(tester);

      // Admin, Ilić, Jovanović, Petrović, Savić, Vlasnik.
      expect(names(tester), [
        'Mina Admin',
        'Nikola Ilić',
        'Ana Jovanović',
        'Jovan Petrović',
        'Milica Savić',
        'Petar Vlasnik',
      ]);
      expect(
        [
          for (final column
              in tester.widget<DataTable>(find.byType(DataTable)).columns)
            (column.label as Text).data,
        ],
        ['Korisnik', 'Uloga', 'Registrovan', 'Status', 'Akcije'],
      );
      expect(find.text('Administrator'), findsWidgets);
      expect(find.text('Vlasnik'), findsWidgets);
      expect(find.text('Aktivan'), findsNWidgets(6));
      expect(find.text('Ukupno naloga: 6'), findsOneWidget);
    });

    testWidgets('pretraga po imenu, bez razlike u slovima i dijakritikama', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'NIKOLA');
      await tester.pumpAndSettle();

      expect(names(tester), ['Nikola Ilić']);
      expect(find.text('Prikazano 1 od 6'), findsOneWidget);
    });

    testWidgets('uloga sužava spisak', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byType(DropdownButton<UserRole?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vlasnik').last);
      await tester.pumpAndSettle();

      expect(names(tester), ['Petar Vlasnik']);
    });

    testWidgets('filteri bez rezultata: poruka, pa poništavanje', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'nepostojeci');
      await tester.pumpAndSettle();

      expect(find.text('Nema naloga za izabrane filtere'), findsOneWidget);
      expect(find.text('Nalozi nisu učitani'), findsNothing);

      await tester.tap(find.text('Poništi filtere'));
      await tester.pumpAndSettle();

      expect(names(tester), hasLength(6));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('nalozi se ne učitaju: razlog i „Pokušaj ponovo“', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      source = _Source(FakeUserAdministrationRepository(users: [admin]))
        ..readError = const ServerUnreachableException();
      final reservations = createBackofficeRepository(delay: Duration.zero);
      await tester.pumpWidget(
        BackofficeApp(
          repository: reservations,
          fieldRepository: createBackofficeFieldRepository(),
          scheduleRepository: createBackofficeScheduleRepository(
            reservations: reservations,
          ),
          userRepository: source,
          owner: admin,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Korisnici'));
      await tester.pumpAndSettle();

      expect(find.text('Nalozi nisu učitani'), findsOneWidget);
      expect(find.text(serverUnreachableMessage), findsOneWidget);

      source.readError = null;
      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(names(tester), ['Mina Admin']);
    });
  });

  group('deaktivacija', () {
    testWidgets('traži potvrdu, pa deaktivira nalog', (tester) async {
      await pumpApp(tester);

      // Dugmad „Deaktiviraj“ su u istom redosledu kao nalozi; prvi je svoj nalog.
      await tester.tap(find.text('Deaktiviraj').at(3));
      await tester.pumpAndSettle();
      expect(find.text('Deaktivirati nalog?'), findsOneWidget);
      expect(
        find.textContaining('Jovan Petrović se više neće moći'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Deaktiviraj'));
      await tester.pumpAndSettle();

      expect(find.text('Deaktiviran'), findsOneWidget);
      expect(find.text('Aktivan'), findsNWidgets(5));
      expect(find.text('Aktiviraj'), findsOneWidget);
    });

    testWidgets('odustajanje ne menja nalog', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Deaktiviraj').at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Deaktiviran'), findsNothing);
      final users = await source.getUsers();
      expect(users.every((u) => u.isActive), isTrue);
    });

    testWidgets('deaktiviran nalog može ponovo da se aktivira, bez potvrde', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Deaktiviraj').at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deaktiviraj'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aktiviraj'));
      await tester.pumpAndSettle();

      expect(find.text('Deaktivirati nalog?'), findsNothing);
      expect(find.text('Deaktiviran'), findsNothing);
      expect(find.text('Aktivan'), findsNWidgets(6));
    });

    testWidgets('svoj nalog ne može da se deaktivira', (tester) async {
      await pumpApp(tester);

      final own = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Deaktiviraj').first,
      );

      expect(own.onPressed, isNull);
      expect(
        find.byTooltip('Ne možete deaktivirati svoj nalog'),
        findsOneWidget,
      );
    });

    testWidgets('greška servera: razlog u traci, nalog ostaje aktivan', (
      tester,
    ) async {
      await pumpApp(tester);
      source.writeError = const ServerUnreachableException();

      await tester.tap(find.text('Deaktiviraj').at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deaktiviraj'));
      await tester.pumpAndSettle();

      expect(find.text(serverUnreachableMessage), findsOneWidget);
      expect(find.text('Deaktiviran'), findsNothing);
    });
  });

  testWidgets(
    'akcije se vide bez pomeranja u stranu u prozoru od 1280 piksela',
    (tester) async {
      await pumpApp(tester, size: const Size(1280, 800));

      for (final button in find.text('Deaktiviraj').evaluate()) {
        final box = button.renderObject! as RenderBox;
        final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
        expect(right, lessThanOrEqualTo(1280));
      }
    },
  );

  group('uski prozor', () {
    testWidgets('nalozi kao kartice, bez prelivanja', (tester) async {
      await pumpApp(tester, size: const Size(700, 1000));

      expect(tester.takeException(), isNull);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsWidgets);
      expect(find.text('Jovan Petrović'), findsOneWidget);
    });

    testWidgets('deaktivacija radi i iz kartice', (tester) async {
      await pumpApp(tester, size: const Size(700, 1000));

      final button = find.text('Deaktiviraj');
      await tester.ensureVisible(button.at(3));
      await tester.pumpAndSettle();
      await tester.tap(button.at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deaktiviraj'));
      await tester.pumpAndSettle();

      expect(find.text('Deaktiviran'), findsOneWidget);
    });
  });
}
