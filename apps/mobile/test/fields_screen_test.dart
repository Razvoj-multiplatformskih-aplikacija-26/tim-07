import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_auth.dart';
import 'package:mobile/data/mobile_availability_repository.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_field_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/data/mobile_schedule_repository.dart';
import 'package:mobile/main.dart';

void main() {
  /// Pokreće aplikaciju na [location] sa lažnim tereni u memoriji.
  Future<MobileFakeFieldRepository> pumpApp(
    WidgetTester tester, {
    String location = '/fields',
    Duration fieldDelay = Duration.zero,
    MobileFakeFieldRepository? fields,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fieldRepository =
        fields ?? createMobileFieldRepository(delay: fieldDelay);
    final auth = createMobileAuthRepository(delay: Duration.zero);
    await auth.logIn(
      email: MobileDemoData.accounts.first.user.email,
      password: MobileDemoData.demoPassword,
    );

    final reservations = createMobileRepository(delay: Duration.zero);

    await tester.pumpWidget(
      MyApp(
        repository: reservations,
        availabilityRepository: createMobileAvailabilityRepository(
          reservations: reservations,
          delay: Duration.zero,
        ),
        fieldRepository: fieldRepository,
        scheduleRepository: createMobileScheduleRepository(),
        authRepository: auth,
        initialLocation: location,
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return fieldRepository;
  }

  FieldsBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(Scaffold).first).read<FieldsBloc>();

  group('četiri stanja kataloga', () {
    testWidgets('učitavanje prikazuje indikator, pa terene', (tester) async {
      await pumpApp(
        tester,
        fieldDelay: const Duration(milliseconds: 300),
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Učitavanje terena...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Učitavanje terena...'), findsNothing);
      expect(find.text('Arena Fudbal'), findsOneWidget);
      expect(find.text('Pronađeno terena: 10'), findsOneWidget);
    });

    testWidgets('greška kaže razlog i nudi „Pokušaj ponovo“', (tester) async {
      final fields = createMobileFieldRepository(delay: Duration.zero)
        ..failNextRequest();
      await pumpApp(tester, fields: fields);

      expect(find.text('Tereni nisu učitani'), findsOneWidget);
      expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(find.text('Arena Fudbal'), findsOneWidget);
    });

    testWidgets('prazan katalog ima svoj prikaz i „Osveži“', (tester) async {
      final fields = createMobileFieldRepository(delay: Duration.zero)
        ..returnEmptyOnNextRequest();
      await pumpApp(tester, fields: fields);

      expect(find.text('Trenutno nema terena'), findsOneWidget);
      expect(find.text('Arena Fudbal'), findsNothing);

      await tester.tap(find.text('Osveži'));
      await tester.pumpAndSettle();

      expect(find.text('Arena Fudbal'), findsOneWidget);
    });

    testWidgets('meni simulacije izaziva grešku sledećeg učitavanja', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Simulacija terena'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Greška pri sledećem zahtevu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Simulacija terena'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Osveži terene'));
      await tester.pumpAndSettle();

      expect(find.text('Tereni nisu učitani'), findsOneWidget);
    });
  });

  group('pretraga, sport i redosled preko Bloc-a', () {
    testWidgets('pretraga sužava listu', (tester) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'padel');
      await tester.pumpAndSettle();

      expect(find.text('Padel Arena'), findsOneWidget);
      expect(find.text('Arena Fudbal'), findsNothing);
      expect(find.text('Pronađeno terena: 1'), findsOneWidget);
      expect(bloc(tester).state.filters.query, 'padel');
    });

    testWidgets('pretraga bez rezultata kaže da nema terena', (tester) async {
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'nema takvog');
      await tester.pumpAndSettle();

      expect(find.text('Nema pronađenih terena.'), findsOneWidget);
      expect(find.text('Pronađeno terena: 0'), findsOneWidget);
      // Ovo nije prazan katalog.
      expect(find.text('Trenutno nema terena'), findsNothing);
    });

    testWidgets('izbor sporta prikazuje samo terene tog sporta', (
      tester,
    ) async {
      await pumpApp(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Tenis'));
      await tester.pumpAndSettle();

      expect(find.text('Tennis Club'), findsOneWidget);
      expect(find.text('Tenis Akademija'), findsOneWidget);
      expect(find.text('Arena Fudbal'), findsNothing);
      expect(bloc(tester).state.filters.sport, SportType.tennis);

      await tester.tap(find.widgetWithText(FilterChip, 'Svi'));
      await tester.pumpAndSettle();

      expect(find.text('Pronađeno terena: 10'), findsOneWidget);
    });

    testWidgets('redosled po ceni', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byType(DropdownButtonFormField<FieldSort>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cena: od najniže').last);
      await tester.pumpAndSettle();

      // Najjeftiniji je Basket 3x3 (1500), pa Basket Centar (2000); u
      // podrazumevanom redosledu je Basket Centar ispred Basket 3x3.
      final cheapest = tester.getTopLeft(find.text('Basket 3x3'));
      final next = tester.getTopLeft(find.text('Basket Centar'));
      expect(cheapest.dy, lessThan(next.dy));
      expect(bloc(tester).state.filters.sort, FieldSort.priceAscending);
    });

    testWidgets('„Resetuj“ vraća pretragu, sport i redosled', (tester) async {
      await pumpApp(tester);
      expect(find.text('Resetuj'), findsNothing);

      await tester.enterText(find.byType(TextField), 'arena');
      await tester.tap(find.widgetWithText(FilterChip, 'Tenis'));
      await tester.pumpAndSettle();
      expect(find.text('Resetuj'), findsOneWidget);

      await tester.tap(find.text('Resetuj'));
      await tester.pumpAndSettle();

      expect(find.text('Pronađeno terena: 10'), findsOneWidget);
      expect(find.text('Resetuj'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(bloc(tester).state.filters, const FieldFilters());
    });

    testWidgets('filteri se pamte kada se napusti katalog i vrati', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField), 'padel');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Padel Arena'));
      await tester.pumpAndSettle();
      expect(find.text('Detalji terena'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Pronađeno terena: 1'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'padel',
      );
    });
  });

  group('detalj terena preko adrese', () {
    testWidgets('prikazuje učitavanje, pa teren', (tester) async {
      await pumpApp(
        tester,
        location: '/fields/3',
        fieldDelay: const Duration(milliseconds: 300),
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Tennis Club'), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Detalji terena'), findsOneWidget);
      expect(find.text('Tennis Club'), findsOneWidget);
    });

    testWidgets('nepostojeći teren kaže da nije pronađen', (tester) async {
      await pumpApp(tester, location: '/fields/999');

      expect(find.text('Teren nije pronađen.'), findsOneWidget);
    });

    testWidgets('adresa koja nije broj kaže da teren nije pronađen', (
      tester,
    ) async {
      await pumpApp(tester, location: '/fields/abc');

      expect(find.text('Teren nije pronađen.'), findsOneWidget);
    });

    testWidgets('neuspeo detalj: poruka i ponovni pokušaj', (tester) async {
      final fields = createMobileFieldRepository(delay: Duration.zero);
      await pumpApp(tester, location: '/fields', fields: fields);

      fields.failNextRequest();
      await tester.tap(find.text('Tennis Club'));
      await tester.pumpAndSettle();

      expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);

      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(find.text('Tennis Club'), findsOneWidget);
      expect(find.text('Server trenutno nije dostupan.'), findsNothing);
    });

    testWidgets('forma za rezervaciju učitava teren po adresi', (tester) async {
      final tomorrow = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 1)),
      );
      final location = Uri(
        path: '/fields/4/reserve',
        queryParameters: {
          'date': tomorrow.toIso8601String(),
          'start': '12:00',
          'end': '13:00',
        },
      ).toString();

      await pumpApp(tester, location: location);

      expect(find.text('Nova rezervacija'), findsOneWidget);
      expect(find.text('Padel Arena'), findsOneWidget);
    });
  });

  group('nazivi terena u rezervacijama dolaze iz kataloga', () {
    testWidgets('moje rezervacije prikazuju nazive iz Bloc-a', (tester) async {
      await pumpApp(tester, location: '/reservations');

      expect(find.text('Arena Fudbal'), findsWidgets);
      expect(find.textContaining('Teren #'), findsNothing);
    });

    testWidgets('dok katalog nije učitan, vidi se zamenski naziv', (
      tester,
    ) async {
      // Katalog kasni, rezervacije ne.
      await pumpApp(
        tester,
        location: '/reservations',
        fieldDelay: const Duration(seconds: 2),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Teren #'), findsWidgets);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.textContaining('Teren #'), findsNothing);
      expect(find.text('Arena Fudbal'), findsWidgets);
    });
  });
}
