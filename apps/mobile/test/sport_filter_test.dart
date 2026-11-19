import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_auth.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_field_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/widgets/field_card.dart';
import 'package:mobile/widgets/sport_icon.dart';

void main() {
  Iterable<SportsField> demoFields(Set<SportType> sports) =>
      MobileDemoData.fields.where((field) => sports.contains(field.sport));

  /// Aplikacija nad zadatim terenima. Široka površina, da se svi čipovi iscrtaju.
  Future<void> pumpApp(
    WidgetTester tester,
    FakeSportsFieldRepository store,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MyApp(
        repository: createMobileRepository(delay: Duration.zero),
        fieldRepository: MobileFakeFieldRepository(store, delay: Duration.zero),
        authRepository: createMobileAuthRepository(delay: Duration.zero),
        initialLocation: '/fields',
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> chipLabels(WidgetTester tester) => [
    for (final chip in tester.widgetList<FilterChip>(find.byType(FilterChip)))
      (chip.label as Text).data!,
  ];

  group('čipovi sportova dolaze iz kataloga', () {
    testWidgets('prikazuju sve sportove koji postoje, redom iz domena', (
      tester,
    ) async {
      await pumpApp(
        tester,
        FakeSportsFieldRepository(fields: MobileDemoData.fields),
      );

      expect(chipLabels(tester), [
        'Svi',
        'Fudbal',
        'Košarka',
        'Tenis',
        'Padel',
        'Odbojka',
        'Plivanje',
        'Futsal',
      ]);
    });

    testWidgets('katalog sa dva sporta ima samo ta dva čipa', (tester) async {
      await pumpApp(
        tester,
        FakeSportsFieldRepository(
          fields: demoFields({SportType.padel, SportType.football}),
        ),
      );

      expect(chipLabels(tester), ['Svi', 'Fudbal', 'Padel']);
      expect(find.widgetWithText(FilterChip, 'Tenis'), findsNothing);
    });

    testWidgets('novi sport na terenu dobija čip posle osvežavanja', (
      tester,
    ) async {
      final store = FakeSportsFieldRepository(
        fields: demoFields({SportType.football, SportType.tennis}),
      );
      await pumpApp(tester, store);
      expect(find.widgetWithText(FilterChip, 'Plivanje'), findsNothing);

      // Vlasnik objavljuje bazen, administrator ga odobrava.
      final created = await store.createField(
        ownerId: const UserId(101),
        name: 'Gradski Bazen',
        description: 'Opis',
        sport: SportType.swimming,
        address: 'Obala 1',
        city: 'Beograd',
        pricePerHour: 1800,
        contactPhone: '060',
        confirmationMode: ConfirmationMode.manual,
      );
      await store.reviewField(
        fieldId: created.id,
        reviewerId: const UserId(1),
        decision: ApprovalStatus.approved,
      );

      await tester.tap(find.byTooltip('Simulacija terena'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Osveži terene'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Plivanje'), findsOneWidget);
      expect(find.text('Gradski Bazen'), findsOneWidget);
    });

    testWidgets('teren koji nije odobren ne daje čip', (tester) async {
      final store = FakeSportsFieldRepository(
        fields: demoFields({SportType.football}),
      );
      await store.createField(
        ownerId: const UserId(101),
        name: 'Čeka odobrenje',
        description: 'Opis',
        sport: SportType.swimming,
        address: 'Obala 1',
        city: 'Beograd',
        pricePerHour: 1800,
        contactPhone: '060',
        confirmationMode: ConfirmationMode.manual,
      );

      await pumpApp(tester, store);

      expect(chipLabels(tester), ['Svi', 'Fudbal']);
    });
  });

  group('izbor sporta', () {
    testWidgets('prikazuje samo terene tog sporta, „Svi“ vraća sve', (
      tester,
    ) async {
      await pumpApp(
        tester,
        FakeSportsFieldRepository(fields: MobileDemoData.fields),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Tenis'));
      await tester.pumpAndSettle();

      expect(find.text('Pronađeno terena: 2'), findsOneWidget);
      expect(find.text('Tennis Club'), findsOneWidget);
      expect(find.text('Arena Fudbal'), findsNothing);
      // Čipovi ostaju, pa se izbor može promeniti.
      expect(find.widgetWithText(FilterChip, 'Fudbal'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Svi'));
      await tester.pumpAndSettle();

      expect(find.text('Pronađeno terena: 10'), findsOneWidget);
    });

    testWidgets('izabrani čip je označen', (tester) async {
      await pumpApp(
        tester,
        FakeSportsFieldRepository(fields: MobileDemoData.fields),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Padel'));
      await tester.pumpAndSettle();

      bool selected(String label) => tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, label))
          .selected;

      expect(selected('Padel'), isTrue);
      expect(selected('Svi'), isFalse);
      expect(selected('Fudbal'), isFalse);
    });
  });

  group('ikonice po sportu (FieldCard prima SportType)', () {
    Future<void> pumpCard(WidgetTester tester, SportType sport) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FieldCard(
              name: 'Teren',
              location: 'Adresa 1',
              sport: sport,
              pricePerHour: 2000,
            ),
          ),
        ),
      );
    }

    testWidgets('kartica prikazuje naziv i ikonicu sporta', (tester) async {
      await pumpCard(tester, SportType.padel);

      expect(find.text('Padel'), findsOneWidget);
      expect(find.byIcon(Icons.sports_tennis), findsWidgets);
    });

    testWidgets('ikonica ne zavisi od teksta naslova', (tester) async {
      // Naziv terena koji liči na drugi sport ne menja ikonicu.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FieldCard(
              name: 'Fudbal Arena',
              location: 'Adresa 1',
              sport: SportType.swimming,
              pricePerHour: 1800,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.pool), findsWidgets);
      expect(find.byIcon(Icons.sports_soccer), findsNothing);
    });

    test('svaki sport ima ikonicu', () {
      for (final sport in SportType.values) {
        expect(sportIcon(sport), isA<IconData>(), reason: sport.name);
      }
    });

    test('ikonice po sportovima', () {
      expect(sportIcon(SportType.football), Icons.sports_soccer);
      expect(sportIcon(SportType.futsal), Icons.sports_soccer);
      expect(sportIcon(SportType.basketball), Icons.sports_basketball);
      expect(sportIcon(SportType.tennis), Icons.sports_tennis);
      expect(sportIcon(SportType.padel), Icons.sports_tennis);
      expect(sportIcon(SportType.volleyball), Icons.sports_volleyball);
      expect(sportIcon(SportType.swimming), Icons.pool);
      expect(sportIcon(SportType.other), Icons.sports);
    });
  });
}
