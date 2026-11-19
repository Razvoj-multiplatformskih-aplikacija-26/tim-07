import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/messages.dart';
import 'package:mobile/data/mobile_auth.dart';
import 'package:mobile/data/mobile_availability_repository.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_fake_repository.dart';
import 'package:mobile/data/mobile_field_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/data/mobile_schedule_repository.dart';
import 'package:mobile/main.dart';

/// Radno vreme koje prvi put ne može da se učita, kao server koji ne radi.
final class _FlakySchedules implements FieldScheduleRepository {
  final FieldScheduleRepository inner;
  bool failing = true;

  _FlakySchedules(this.inner);

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) async {
    if (failing) throw const ServerUnreachableException();
    return inner.getSchedules(fieldId);
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) => inner.getBlockedPeriods(fieldId, from: from, to: to);

  @override
  Future<void> replaceSchedules(
    FieldId fieldId,
    List<FieldSchedule> schedules,
  ) => inner.replaceSchedules(fieldId, schedules);

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) =>
      inner.addBlockedPeriod(period);

  @override
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id) =>
      inner.removeBlockedPeriod(fieldId, id);
}

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final marko = MobileDemoData.accounts.first.user;

  String reserve(
    int fieldId,
    DateTime day, {
    String start = '12:00',
    String end = '13:00',
  }) => Uri(
    path: '/fields/$fieldId/reserve',
    queryParameters: {
      'date': day.toIso8601String(),
      'start': start,
      'end': end,
    },
  ).toString();

  Future<MobileFakeReservationRepository> pumpForm(
    WidgetTester tester,
    String location, {
    FieldScheduleRepository? schedules,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reservations = createMobileRepository(delay: Duration.zero);
    final auth = createMobileAuthRepository(delay: Duration.zero);
    await auth.logIn(email: marko.email, password: MobileDemoData.demoPassword);

    await tester.pumpWidget(
      MyApp(
        repository: reservations,
        fieldRepository: createMobileFieldRepository(delay: Duration.zero),
        scheduleRepository: schedules ?? createMobileScheduleRepository(),
        availabilityRepository: createMobileAvailabilityRepository(
          reservations: reservations,
          delay: Duration.zero,
        ),
        authRepository: auth,
        initialLocation: location,
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return reservations;
  }

  Future<void> typeTimes(
    WidgetTester tester, {
    String? start,
    String? end,
  }) async {
    if (start != null) {
      await tester.enterText(find.byType(TextField).at(0), start);
    }
    if (end != null) {
      await tester.enterText(find.byType(TextField).at(1), end);
    }
    await tester.pumpAndSettle();
  }

  group('provera iz Bloc-a', () {
    testWidgets('prikazuje teren, cenu i ime prijavljenog korisnika', (
      tester,
    ) async {
      await pumpForm(tester, reserve(1, tomorrow));

      expect(find.text('Nova rezervacija'), findsOneWidget);
      expect(find.text('Arena Fudbal'), findsOneWidget);
      // Arena Fudbal košta 3500 po satu.
      expect(find.text('Cena: 3500 RSD'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, marko.fullName),
        findsOneWidget,
      );
    });

    testWidgets('cena prati unos, srazmerno trajanju', (tester) async {
      await pumpForm(tester, reserve(1, tomorrow));

      await typeTimes(tester, start: '12:00', end: '13:30');

      expect(find.text('Cena: 5250 RSD'), findsOneWidget);
    });

    testWidgets('pogrešan oblik vremena se prijavljuje odmah', (tester) async {
      await pumpForm(tester, reserve(1, tomorrow));

      await typeTimes(tester, start: 'abc');

      expect(
        find.text('Unesite vreme u obliku HH:mm, na primer 18:00.'),
        findsOneWidget,
      );
      expect(find.text('Cena: 3500 RSD'), findsNothing);
    });

    testWidgets('pravilo iz domena se prikazuje porukom iz paketa messages', (
      tester,
    ) async {
      await pumpForm(tester, reserve(1, tomorrow));

      await typeTimes(tester, end: '23:30');

      expect(
        find.text(validationMessage(const OutsideWorkingHours())),
        findsOneWidget,
      );
    });

    testWidgets('kraj pre početka', (tester) async {
      await pumpForm(tester, reserve(1, tomorrow));

      await typeTimes(tester, start: '15:00', end: '14:00');

      expect(
        find.text(validationMessage(const InvalidTimeRange())),
        findsOneWidget,
      );
    });

    testWidgets('neispravan unos se ne šalje', (tester) async {
      final reservations = await pumpForm(tester, reserve(1, tomorrow));
      final before = await reservations.getReservationsByUser(marko.id);

      await typeTimes(tester, end: '23:30');
      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsOneWidget);
      expect(
        await reservations.getReservationsByUser(marko.id),
        hasLength(before.length),
      );
    });
  });

  group('slanje', () {
    testWidgets('uspeh: obaveštenje, povratak i nova rezervacija u spisku', (
      tester,
    ) async {
      final reservations = await pumpForm(tester, reserve(1, tomorrow));
      final before = await reservations.getReservationsByUser(marko.id);

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsNothing);
      expect(find.text('Rezervacija je uspešno kreirana!'), findsOneWidget);
      expect(
        await reservations.getReservationsByUser(marko.id),
        hasLength(before.length + 1),
      );
    });

    testWidgets('server odbija termin koji klijent nije mogao da vidi', (
      tester,
    ) async {
      // Demo rezervacija 2 pripada drugom korisniku: teren 2, za dva dana u 12 h.
      final taken = today.add(const Duration(days: 2));
      final reservations = await pumpForm(tester, reserve(2, taken));
      final before = await reservations.getReservationsByUser(marko.id);

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      // Poruka je ista kao kada bi isto pravilo proverio klijent.
      expect(
        find.text(validationMessage(const SlotAlreadyTaken())),
        findsWidgets,
      );
      // Ostaje na formi, sa unosom.
      expect(find.text('Nova rezervacija'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12:00'), findsOneWidget);
      expect(
        await reservations.getReservationsByUser(marko.id),
        hasLength(before.length),
      );
    });

    testWidgets('posle odbijanja korisnik bira drugi termin i uspeva', (
      tester,
    ) async {
      final taken = today.add(const Duration(days: 2));
      final reservations = await pumpForm(tester, reserve(2, taken));
      final before = await reservations.getReservationsByUser(marko.id);

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();
      await typeTimes(tester, start: '18:00', end: '19:00');
      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsNothing);
      expect(
        await reservations.getReservationsByUser(marko.id),
        hasLength(before.length + 1),
      );
    });

    testWidgets('nema servera: poruka, unos ostaje, ponovno slanje radi', (
      tester,
    ) async {
      final reservations = await pumpForm(tester, reserve(1, tomorrow));

      reservations.failNextRequest();
      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Server trenutno nije dostupan.'), findsWidgets);
      expect(find.text('Nova rezervacija'), findsOneWidget);

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsNothing);
    });

    testWidgets('dok traje slanje dugme je zaključano', (tester) async {
      final reservations = createMobileRepository(
        delay: const Duration(milliseconds: 400),
      );
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = createMobileAuthRepository(delay: Duration.zero);
      await auth.logIn(
        email: marko.email,
        password: MobileDemoData.demoPassword,
      );
      await tester.pumpWidget(
        MyApp(
          repository: reservations,
          fieldRepository: createMobileFieldRepository(delay: Duration.zero),
          scheduleRepository: createMobileScheduleRepository(),
          availabilityRepository: createMobileAvailabilityRepository(
            reservations: reservations,
            delay: Duration.zero,
          ),
          authRepository: auth,
          initialLocation: reserve(1, tomorrow),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Slanje rezervacije...'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull,
      );

      await tester.pumpAndSettle();
      // Osvežavanje spiska posle uspeha ima svoje kašnjenje.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Nova rezervacija'), findsNothing);
    });
  });

  group('priprema', () {
    testWidgets('ako se podaci ne učitaju, nudi „Pokušaj ponovo“', (
      tester,
    ) async {
      final schedules = _FlakySchedules(createMobileScheduleRepository());
      await pumpForm(tester, reserve(1, tomorrow), schedules: schedules);

      expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);
      expect(find.text('Potvrdi rezervaciju'), findsNothing);

      schedules.failing = false;
      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(find.text('Potvrdi rezervaciju'), findsOneWidget);
      expect(find.text('Cena: 3500 RSD'), findsOneWidget);
    });
  });
}
