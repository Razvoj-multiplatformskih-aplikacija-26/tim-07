import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/widgets/reservation_filters.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late BackofficeFakeReservationRepository repository;

  Future<void> pumpApp(
    WidgetTester tester, {
    BackofficeFakeReservationRepository? source,
    Size size = const Size(1600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repository = source ?? createBackofficeRepository(delay: Duration.zero);
    await tester.pumpWidget(backofficeApp(repository));
    await tester.pumpAndSettle();
  }

  /// Redosled id-jeva u tabeli, odozgo nadole.
  List<int> rows(WidgetTester tester) => [
    for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
      (row.key! as ValueKey<int>).value,
  ];

  ReservationListBloc bloc(WidgetTester tester) => tester
      .element(find.byType(ReservationFilters))
      .read<ReservationListBloc>();

  Future<void> choose(WidgetTester tester, Type dropdown, String option) async {
    await tester.tap(find.byType(dropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // Pretraga se učitava tek kada vlasnik prestane da kuca.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('filteri', () {
    testWidgets('traka sa filterima i svih sedam rezervacija po početku', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text('Pretraga po korisniku'), findsOneWidget);
      expect(find.text('Teren'), findsWidgets);
      expect(find.text('Stanje'), findsOneWidget);
      expect(find.text('Datum: Svi datumi'), findsOneWidget);
      expect(find.text('Poništi filtere'), findsNothing);
      expect(rows(tester), [6, 1, 4, 2, 3, 5, 7]);
      expect(find.text('Prikazano 1-7 od 7'), findsOneWidget);
    });

    testWidgets('po stanju', (tester) async {
      await pumpApp(tester);

      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');

      expect(rows(tester), [4, 2, 5]);
      expect(find.text('Poništi filtere'), findsOneWidget);
    });

    testWidgets('po terenu, sa spiskom terena iz podataka', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byType(DropdownButton<FieldId?>));
      await tester.pumpAndSettle();
      for (final field in BackofficeDemoData.fields) {
        expect(find.text(field.name), findsWidgets);
      }
      expect(find.text('Svi tereni'), findsWidgets);
      await tester.tap(find.text(BackofficeDemoData.fields[1].name).last);
      await tester.pumpAndSettle();

      expect(rows(tester), [4, 2]);
    });

    testWidgets('teren i stanje rade zajedno', (tester) async {
      await pumpApp(tester);

      await choose(
        tester,
        DropdownButton<FieldId?>,
        BackofficeDemoData.fields[0].name,
      );
      await choose(tester, DropdownButton<ReservationStatus?>, 'Potvrđena');

      expect(rows(tester), [1]);
    });

    testWidgets('po datumu, i oznaka opsega na dugmetu', (tester) async {
      await pumpApp(tester);
      final today = DateUtils.dateOnly(DateTime.now());

      bloc(tester).add(
        ReservationListDatesChanged(
          from: today.add(const Duration(days: 2)),
          to: today.add(const Duration(days: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(rows(tester), [4, 2, 3]);
      expect(find.textContaining('Datum: '), findsOneWidget);
      expect(find.text('Datum: Svi datumi'), findsNothing);

      await tester.tap(find.byTooltip('Obriši datume'));
      await tester.pumpAndSettle();
      expect(rows(tester), hasLength(7));
      expect(find.text('Datum: Svi datumi'), findsOneWidget);
    });

    testWidgets('poništavanje vraća sve rezervacije i prazno polje pretrage', (
      tester,
    ) async {
      await pumpApp(tester);
      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');
      await search(tester, 'nikola');
      expect(rows(tester), [4]);

      await tester.tap(find.text('Poništi filtere'));
      await tester.pumpAndSettle();

      expect(rows(tester), hasLength(7));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });
  });

  group('pretraga po korisniku', () {
    testWidgets('traži u imenu, bez obzira na slova i dijakritike', (
      tester,
    ) async {
      await pumpApp(tester);

      await search(tester, 'PETROVIC');

      expect(rows(tester), [1, 3]);
    });

    testWidgets('traži i po emailu', (tester) async {
      await pumpApp(tester);

      await search(tester, 'milica');

      expect(rows(tester), [5]);
    });

    testWidgets('dugme za brisanje pretrage vraća sve', (tester) async {
      await pumpApp(tester);
      await search(tester, 'nikola ilić');
      expect(rows(tester), [4, 7]);

      await tester.tap(find.byTooltip('Obriši pretragu'));
      await tester.pumpAndSettle();

      expect(rows(tester), hasLength(7));
    });

    testWidgets('slovo P u polju pretrage ne potvrđuje izabranu rezervaciju', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('#4'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      final reservation = await repository.getReservationById(
        const ReservationId(4),
      );
      expect(reservation!.status, ReservationStatus.pending);
    });
  });

  group('prazan rezultat', () {
    testWidgets('filteri bez rezultata nisu greška', (tester) async {
      await pumpApp(tester);

      await search(tester, 'nepostojeci korisnik');

      expect(find.text('Nema rezervacija za izabrane filtere'), findsOneWidget);
      expect(find.text('Rezervacije nisu učitane'), findsNothing);
      expect(find.byType(DataTable), findsNothing);
      // Filteri ostaju na ekranu da bi mogli da se promene.
      expect(find.text('Pretraga po korisniku'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Poništi filtere'));
      await tester.pumpAndSettle();
      expect(rows(tester), hasLength(7));
    });

    testWidgets('bez ijedne rezervacije i bez filtera: „Nema rezervacija“', (
      tester,
    ) async {
      await pumpApp(
        tester,
        source: createBackofficeRepository(delay: Duration.zero)
          ..returnEmptyOnNextRequest(),
      );

      expect(find.text('Nema rezervacija'), findsOneWidget);
      expect(find.text('Nema rezervacija za izabrane filtere'), findsNothing);
    });
  });

  group('sortiranje', () {
    testWidgets('klik na zaglavlje sortira, drugi klik obrće smer', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.text('Korisnik'));
      await tester.pumpAndSettle();
      // Ilić, Jovanović, Petrović, Savić.
      expect(rows(tester), [4, 7, 2, 6, 1, 3, 5]);
      var table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.sortColumnIndex, 2);
      expect(table.sortAscending, isTrue);

      await tester.tap(find.text('Korisnik'));
      await tester.pumpAndSettle();
      expect(rows(tester), [5, 1, 3, 2, 6, 4, 7]);
      table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.sortAscending, isFalse);
    });

    testWidgets('sortiranje po id i po terenu', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('ID'));
      await tester.pumpAndSettle();
      expect(rows(tester), [1, 2, 3, 4, 5, 6, 7]);

      await tester.tap(find.text('Teren').last);
      await tester.pumpAndSettle();
      // Arena Fudbal (1, 5, 7), Basket Park (3, 6), Tenis Centar (2, 4).
      expect(rows(tester), [1, 5, 7, 3, 6, 2, 4]);
    });

    testWidgets('sortiranje ostaje kada se promeni filter', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('ID'));
      await tester.pumpAndSettle();

      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');

      expect(rows(tester), [2, 4, 5]);
    });
  });

  group('izbor', () {
    testWidgets('ostaje izabrana dok je u filtriranoj listi', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('#4'));
      await tester.pumpAndSettle();
      expect(find.text('Rezervacija #4'), findsOneWidget);

      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');

      expect(rows(tester), [4, 2, 5]);
      expect(find.text('Rezervacija #4'), findsOneWidget);
    });

    testWidgets('briše se kada je filter izbaci', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('#4'));
      await tester.pumpAndSettle();

      await choose(tester, DropdownButton<ReservationStatus?>, 'Potvrđena');

      expect(find.text('Rezervacija #4'), findsNothing);
      expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
    });

    testWidgets('potvrda iz tabele osvežava listu i izbacuje izabranu', (
      tester,
    ) async {
      await pumpApp(tester);
      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');
      await tester.tap(find.text('#4'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      // Rezervacija 4 je sada potvrđena, pa više nije u „na čekanju“.
      expect(rows(tester), [2, 5]);
      expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
    });

    testWidgets('strelice se kreću po redosledu iz izvora', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('ID'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ID'));
      await tester.pumpAndSettle();
      expect(rows(tester).first, 7);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Rezervacija #7'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(find.text('Rezervacija #6'), findsOneWidget);
    });
  });

  group('strane', () {
    BackofficeFakeReservationRepository many() {
      final today = DateUtils.dateOnly(DateTime.now());

      return BackofficeFakeReservationRepository(
        FakeReservationRepository(
          fields: BackofficeDemoData.fields,
          users: BackofficeDemoData.users,
          reservations: [
            for (var i = 1; i <= 45; i++)
              Reservation(
                id: ReservationId(i),
                fieldId: FieldId(1 + i % 3),
                userId: UserId(1 + i % 4),
                startTime: today.add(
                  Duration(days: 3 + i ~/ 10, hours: 8 + i % 12),
                ),
                endTime: today.add(
                  Duration(days: 3 + i ~/ 10, hours: 9 + i % 12),
                ),
                totalPrice: 3000,
                status: i.isEven
                    ? ReservationStatus.confirmed
                    : ReservationStatus.pending,
                createdAt: today,
              ),
          ],
        ),
        delay: Duration.zero,
      );
    }

    testWidgets('prva strana ima 20 redova i ukupan broj', (tester) async {
      await pumpApp(tester, source: many());

      expect(rows(tester), hasLength(20));
      expect(find.text('Prikazano 1-20 od 45'), findsOneWidget);
      expect(find.text('Strana 1 od 3'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('dugmad prelaze na sledeću i prethodnu stranu', (tester) async {
      await pumpApp(tester, source: many());

      await tester.tap(find.byTooltip('Sledeća strana'));
      await tester.pumpAndSettle();
      expect(find.text('Prikazano 21-40 od 45'), findsOneWidget);
      expect(find.text('Strana 2 od 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Sledeća strana'));
      await tester.pumpAndSettle();
      expect(find.text('Prikazano 41-45 od 45'), findsOneWidget);
      expect(rows(tester), hasLength(5));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byTooltip('Prethodna strana'));
      await tester.pumpAndSettle();
      expect(find.text('Strana 2 od 3'), findsOneWidget);
    });

    testWidgets('PageDown i PageUp menjaju stranu', (tester) async {
      await pumpApp(tester, source: many());

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(find.text('Strana 2 od 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(find.text('Strana 1 od 3'), findsOneWidget);
    });

    testWidgets('filter vraća na prvu stranu i menja ukupan broj', (
      tester,
    ) async {
      await pumpApp(tester, source: many());
      await tester.tap(find.byTooltip('Sledeća strana'));
      await tester.pumpAndSettle();

      await choose(tester, DropdownButton<ReservationStatus?>, 'Potvrđena');

      // Parni id-jevi od 2 do 44: 22 rezervacije.
      expect(find.text('Prikazano 1-20 od 22'), findsOneWidget);
      expect(find.text('Strana 1 od 2'), findsOneWidget);
    });

    testWidgets('izabrana rezervacija sa druge strane se briše pri prelasku', (
      tester,
    ) async {
      await pumpApp(tester, source: many());
      await tester.tap(find.textContaining('#').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Rezervacija #'), findsOneWidget);

      await tester.tap(find.byTooltip('Sledeća strana'));
      await tester.pumpAndSettle();

      expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
    });
  });

  group('greške i uski prozor', () {
    testWidgets(
      'greška pri filtriranju: razlog, filteri ostaju, ponovni pokušaj',
      (tester) async {
        await pumpApp(tester);

        repository.failNextRequest();
        await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');

        expect(find.text('Rezervacije nisu učitane'), findsOneWidget);
        expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);
        expect(find.text('Pretraga po korisniku'), findsOneWidget);

        await tester.tap(find.text('Pokušaj ponovo'));
        await tester.pumpAndSettle();

        // Isti filter je i dalje izabran.
        expect(rows(tester), [4, 2, 5]);
      },
    );

    testWidgets('uski prozor: filteri i lista bez prelivanja', (tester) async {
      await pumpApp(tester, size: const Size(700, 1000));

      expect(tester.takeException(), isNull);
      expect(find.text('Pretraga po korisniku'), findsOneWidget);

      await choose(tester, DropdownButton<ReservationStatus?>, 'Na čekanju');

      expect(tester.takeException(), isNull);
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Prikazano 1-3 od 3'), findsOneWidget);
    });
  });
}
