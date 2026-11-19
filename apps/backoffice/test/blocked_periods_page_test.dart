import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/text/labels.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/messages.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));

  /// Rezervacija koja je potvrđena sutra od 10 do 11 na terenu 1.
  Reservation confirmedTomorrow() => Reservation(
    id: const ReservationId(900),
    fieldId: const FieldId(1),
    userId: const UserId(1),
    startTime: tomorrow.add(const Duration(hours: 10)),
    endTime: tomorrow.add(const Duration(hours: 11)),
    totalPrice: 3000,
    status: ReservationStatus.confirmed,
    createdAt: today,
  );

  BackofficeFakeReservationRepository reservationsWith(
    List<Reservation> existing,
  ) => BackofficeFakeReservationRepository(
    FakeReservationRepository(
      reservations: existing,
      fields: BackofficeDemoData.fields,
      schedules: BackofficeDemoData.schedules,
    ),
    delay: Duration.zero,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    BackofficeFakeReservationRepository? reservations,
    SportsFieldRepository? fields,
    AppUser? owner,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final source = reservations ?? reservationsWith(const []);
    await tester.pumpWidget(
      BackofficeApp(
        repository: source,
        fieldRepository: fields ?? createBackofficeFieldRepository(),
        scheduleRepository: createBackofficeScheduleRepository(
          reservations: source,
        ),
        owner: owner ?? BackofficeDemoData.owner,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Blokade'));
    if (settle) await tester.pumpAndSettle();
  }

  BlockedPeriodsBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(NavigationRail)).read<BlockedPeriodsBloc>();

  Future<void> addWithDefaults(WidgetTester tester, {String? reason}) async {
    await tester.tap(find.text('Dodaj blokadu'));
    await tester.pumpAndSettle();
    if (reason != null) {
      await tester.enterText(find.byType(TextField), reason);
    }
    await tester.tap(find.text('Blokiraj'));
    await tester.pumpAndSettle();
  }

  group('stanja stranice', () {
    testWidgets('prikazuje blokade izabranog terena', (tester) async {
      await pumpPage(tester);

      expect(find.text('Održavanje terena'), findsOneWidget);
      // Blokada drugog terena (turnir) se ne vidi dok se on ne izabere.
      expect(find.text('Turnir'), findsNothing);
      expect(find.text('Dodaj blokadu'), findsOneWidget);
    });

    testWidgets('izbor drugog terena prikazuje njegove blokade', (
      tester,
    ) async {
      await pumpPage(tester);
      final secondName = BackofficeDemoData.fields[1].name;

      await tester.tap(find.byType(DropdownButton<FieldId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(secondName).last);
      await tester.pumpAndSettle();

      expect(find.text('Turnir'), findsOneWidget);
      expect(find.text('Održavanje terena'), findsNothing);
    });

    testWidgets('vidi samo terene vlasnika', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byType(DropdownButton<FieldId>));
      await tester.pumpAndSettle();

      for (final field in BackofficeDemoData.fields) {
        expect(find.text(field.name), findsWidgets);
      }
    });

    testWidgets('vlasnik bez terena dobija objašnjenje', (tester) async {
      final stranger = AppUser(
        id: const UserId(777),
        firstName: 'Drugi',
        lastName: 'Vlasnik',
        email: 'drugi@example.com',
        phoneNumber: '060',
        dateOfBirth: DateTime(1990),
        role: UserRole.owner,
        createdAt: DateTime(2025),
      );
      await pumpPage(tester, owner: stranger);

      expect(find.text('Nemate nijedan teren'), findsOneWidget);
      expect(find.text('Dodaj blokadu'), findsNothing);
    });

    testWidgets('teren bez blokada kaže da su termini otvoreni', (
      tester,
    ) async {
      await pumpPage(tester);
      final third = BackofficeDemoData.fields[2].name;

      await tester.tap(find.byType(DropdownButton<FieldId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(third).last);
      await tester.pumpAndSettle();

      expect(find.text('Nema blokada'), findsOneWidget);
    });
  });

  group('dodavanje blokade', () {
    testWidgets('uspeh: blokada se vidi u spisku sa razlogom', (tester) async {
      await pumpPage(tester);

      await addWithDefaults(tester, reason: 'Turnir veterana');

      expect(find.text('Turnir veterana'), findsOneWidget);
      expect(
        find.text(
          formatDateTimeRange(
            tomorrow.add(const Duration(hours: 10)),
            tomorrow.add(const Duration(hours: 12)),
          ),
        ),
        findsOneWidget,
      );
      // Stara blokada ostaje, nova je pre nje po početku.
      expect(find.text('Održavanje terena'), findsOneWidget);
    });

    testWidgets('odustajanje ne dodaje ništa', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Dodaj blokadu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('preko potvrđene rezervacije: razlog umesto blokade', (
      tester,
    ) async {
      await pumpPage(
        tester,
        reservations: reservationsWith([confirmedTomorrow()]),
      );
      final before = find.byType(Card).evaluate().length;

      // Početna ponuda je sutra od 10 do 12, a rezervacija je od 10 do 11.
      await addWithDefaults(tester);

      expect(
        find.text('U izabranom periodu već postoji potvrđena rezervacija.'),
        findsOneWidget,
      );
      expect(find.byType(Card).evaluate().length, before);
    });

    testWidgets('rezervacija na čekanju ne sprečava blokadu', (tester) async {
      final pending = Reservation(
        id: const ReservationId(901),
        fieldId: const FieldId(1),
        userId: const UserId(1),
        startTime: tomorrow.add(const Duration(hours: 10)),
        endTime: tomorrow.add(const Duration(hours: 11)),
        totalPrice: 3000,
        status: ReservationStatus.pending,
        createdAt: today,
      );
      await pumpPage(tester, reservations: reservationsWith([pending]));

      await addWithDefaults(tester, reason: 'Čišćenje');

      expect(find.text('Čišćenje'), findsOneWidget);
    });

    testWidgets('razlog nestaje kada sledeća blokada uspe', (tester) async {
      await pumpPage(
        tester,
        reservations: reservationsWith([confirmedTomorrow()]),
      );
      await addWithDefaults(tester);
      expect(
        find.text('U izabranom periodu već postoji potvrđena rezervacija.'),
        findsOneWidget,
      );

      // Isti period posle otkazivanja rezervacije (preko Bloc-a, kao posle osvežavanja).
      bloc(tester).add(
        BlockedPeriodAddRequested(
          startTime: tomorrow.add(const Duration(hours: 18)),
          endTime: tomorrow.add(const Duration(hours: 20)),
          reason: 'Večernja blokada',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('U izabranom periodu već postoji potvrđena rezervacija.'),
        findsNothing,
      );
      expect(find.text('Večernja blokada'), findsOneWidget);
    });

    testWidgets('kraj pre početka i prošlost imaju svoj razlog', (
      tester,
    ) async {
      await pumpPage(tester);

      bloc(tester).add(
        BlockedPeriodAddRequested(
          startTime: tomorrow.add(const Duration(hours: 12)),
          endTime: tomorrow.add(const Duration(hours: 10)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Kraj blokade mora biti posle početka.'),
        findsOneWidget,
      );

      bloc(tester).add(
        BlockedPeriodAddRequested(
          startTime: today.subtract(const Duration(days: 2)),
          endTime: today.subtract(const Duration(days: 2, hours: -2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Blokada mora da obuhvata budući termin.'),
        findsOneWidget,
      );
    });
  });

  group('uklanjanje blokade', () {
    testWidgets('traži potvrdu, pa uklanja blokadu', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Ukloni blokadu'));
      await tester.pumpAndSettle();
      expect(find.text('Ukloniti blokadu?'), findsOneWidget);

      await tester.tap(find.text('Da, ukloni'));
      await tester.pumpAndSettle();

      expect(find.text('Održavanje terena'), findsNothing);
      expect(find.text('Nema blokada'), findsOneWidget);
    });

    testWidgets('odustajanje čuva blokadu', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Ukloni blokadu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      expect(find.text('Održavanje terena'), findsOneWidget);
    });
  });

  group('greške izvora', () {
    testWidgets('teren se ne učita: razlog i „Pokušaj ponovo“', (tester) async {
      await pumpPage(tester, fields: _FailingFields(), settle: false);
      await tester.pumpAndSettle();

      expect(find.text('Blokade nisu učitane'), findsOneWidget);
      expect(find.text(serverUnreachableMessage), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
    });
  });
}

/// Spisak terena koji ne može da se učita.
final class _FailingFields implements SportsFieldRepository {
  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getFields() async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getPublicFields() async =>
      throw const ServerUnreachableException();

  @override
  Future<SportsField?> getFieldById(FieldId id) async =>
      throw const ServerUnreachableException();

  @override
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  }) async => throw const ServerUnreachableException();

  @override
  Future<SportsField> updateField(SportsField field) async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async =>
      throw const ServerUnreachableException();

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async => throw const ServerUnreachableException();
}
