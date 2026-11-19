import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/mobile_auth.dart';
import 'package:mobile/data/mobile_availability_repository.dart';
import 'package:mobile/data/mobile_demo_data.dart';
import 'package:mobile/data/mobile_fake_repository.dart';
import 'package:mobile/data/mobile_field_repository.dart';
import 'package:mobile/data/mobile_repository.dart';
import 'package:mobile/data/mobile_schedule_repository.dart';
import 'package:mobile/main.dart';
import 'package:mobile/screens/field_details_screen.dart';
import 'package:mobile/text/reservation_texts.dart';

void main() {
  final tomorrow = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );

  /// Detalj terena 1 (Arena Fudbal). Demo rezervacija 1 je sutra od 10 do 11.
  Future<MobileFakeReservationRepository> pumpApp(
    WidgetTester tester, {
    MobileFakeAvailabilityRepository Function(MobileFakeReservationRepository)?
    availability,
    bool signedIn = true,
    Duration availabilityDelay = Duration.zero,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reservations = createMobileRepository(delay: Duration.zero);
    final auth = createMobileAuthRepository(delay: Duration.zero);
    if (signedIn) {
      await auth.logIn(
        email: MobileDemoData.accounts.first.user.email,
        password: MobileDemoData.demoPassword,
      );
    }

    await tester.pumpWidget(
      MyApp(
        repository: reservations,
        fieldRepository: createMobileFieldRepository(delay: Duration.zero),
        scheduleRepository: createMobileScheduleRepository(),
        availabilityRepository:
            availability?.call(reservations) ??
            createMobileAvailabilityRepository(
              reservations: reservations,
              delay: availabilityDelay,
            ),
        authRepository: auth,
        initialLocation: '/fields/1',
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return reservations;
  }

  AvailabilityBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(FieldDetailsScreen)).read<AvailabilityBloc>();

  Future<void> selectDay(WidgetTester tester, DateTime day) async {
    bloc(tester).add(AvailabilityDaySelected(day));
    await tester.pumpAndSettle();
  }

  Finder tile(String range) => find.widgetWithText(ListTile, range);

  Finder statusOf(String range, String label) =>
      find.descendant(of: tile(range), matching: find.text(label));

  group('četiri stanja termina', () {
    testWidgets('učitavanje prikazuje indikator, pa termine', (tester) async {
      await pumpApp(
        tester,
        availabilityDelay: const Duration(milliseconds: 300),
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Slobodnih termina', findRichText: true), findsNothing);
      expect(find.byType(ListTile), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('greška kaže razlog i nudi „Pokušaj ponovo“', (tester) async {
      await pumpApp(
        tester,
        availability: (reservations) => createMobileAvailabilityRepository(
          reservations: reservations,
          delay: Duration.zero,
        )..failNextRequest(),
      );

      expect(find.text('Server trenutno nije dostupan.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(find.text('Server trenutno nije dostupan.'), findsNothing);
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('dan na koji teren ne radi ima svoj prikaz', (tester) async {
      await pumpApp(
        tester,
        availability: (reservations) => MobileFakeAvailabilityRepository(
          FakeAvailabilityRepository(
            reservations: reservations.store,
            schedules: [
              for (final schedule in MobileDemoData.schedules)
                FieldSchedule(
                  fieldId: schedule.fieldId,
                  dayOfWeek: schedule.dayOfWeek,
                  opensAt: schedule.opensAt,
                  closesAt: schedule.closesAt,
                  isOpen: false,
                ),
            ],
          ),
          delay: Duration.zero,
        ),
      );

      expect(find.text('Teren ne radi izabranog dana.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
  });

  group('termini iz podataka, ne iz fiksne liste', () {
    testWidgets('prate radno vreme terena (08-23), ne dvanaest fiksnih sati', (
      tester,
    ) async {
      await pumpApp(tester);
      await selectDay(tester, tomorrow);

      // Radno vreme je 08-23, pa ima 15 termina; stara fiksna lista je stajala na 20 h.
      expect(tile('08:00 - 09:00'), findsOneWidget);
      expect(tile('22:00 - 23:00'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(15));
      expect(find.text('Slobodnih termina: 14 od 15'), findsOneWidget);
    });

    testWidgets('zauzet termin dolazi iz rezervacije', (tester) async {
      await pumpApp(tester);
      await selectDay(tester, tomorrow);

      // Demo rezervacija 1: teren 1, sutra od 10 do 11.
      expect(statusOf('10:00 - 11:00', 'Zauzet termin'), findsOneWidget);
      expect(statusOf('11:00 - 12:00', 'Slobodan termin'), findsOneWidget);
      expect(statusOf('09:00 - 10:00', 'Slobodan termin'), findsOneWidget);
    });

    testWidgets('prošli termini današnjeg dana su označeni', (tester) async {
      final noon = DateTime.now().copyWith(
        hour: 12,
        minute: 0,
        second: 0,
        millisecond: 0,
        microsecond: 0,
      );
      await pumpApp(
        tester,
        availability: (reservations) => createMobileAvailabilityRepository(
          reservations: reservations,
          delay: Duration.zero,
          clock: () => noon,
        ),
      );

      // Sada je 12:00: termini od 08 do 12 su počeli.
      expect(find.text('Termin je prošao'), findsNWidgets(5));
      expect(statusOf('13:00 - 14:00', 'Slobodan termin'), findsOneWidget);
      // Prošao termin se ne može otvoriti.
      expect(tester.widget<ListTile>(tile('09:00 - 10:00')).onTap, isNull);
    });

    testWidgets('promena dana šalje događaj Bloc-u i menja natpis', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(
        find.text('Datum: ${formatDate(DateUtils.dateOnly(DateTime.now()))}'),
        findsOneWidget,
      );

      await selectDay(tester, tomorrow);

      expect(find.text('Datum: ${formatDate(tomorrow)}'), findsOneWidget);
      expect(bloc(tester).state.day, tomorrow);
    });

    testWidgets('birač datuma se otvara i potvrđuje isti dan', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.textContaining('Datum:'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsNothing);
      expect(bloc(tester).state, isA<AvailabilityLoaded>());
    });
  });

  group('rezervisanje iz termina', () {
    testWidgets('slobodan termin otvara formu sa tim vremenom', (tester) async {
      await pumpApp(tester);
      await selectDay(tester, tomorrow);

      await tester.tap(tile('12:00 - 13:00'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12:00'), findsOneWidget);
      expect(find.widgetWithText(TextField, '13:00'), findsOneWidget);
    });

    testWidgets('zauzet termin se ne može otvoriti', (tester) async {
      await pumpApp(tester);
      await selectDay(tester, tomorrow);

      await tester.tap(tile('10:00 - 11:00'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsNothing);
      expect(find.text('Detalji terena'), findsOneWidget);
    });

    testWidgets('posle rezervacije se termin osvežava i vidi se kao zauzet', (
      tester,
    ) async {
      await pumpApp(tester);
      await selectDay(tester, tomorrow);
      expect(statusOf('12:00 - 13:00', 'Slobodan termin'), findsOneWidget);

      await tester.tap(tile('12:00 - 13:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Detalji terena'), findsOneWidget);
      expect(statusOf('12:00 - 13:00', 'Zauzet termin'), findsOneWidget);
      expect(find.text('Slobodnih termina: 13 od 15'), findsOneWidget);
    });

    testWidgets('bez prijave slobodan termin vodi na prijavu', (tester) async {
      await pumpApp(tester, signedIn: false);
      await selectDay(tester, tomorrow);

      await tester.tap(tile('12:00 - 13:00'));
      await tester.pumpAndSettle();

      expect(
        find.text('Prijavite se da biste rezervisali teren'),
        findsOneWidget,
      );
      expect(find.text('Nova rezervacija'), findsNothing);
    });

    testWidgets('termini se vide i bez prijave', (tester) async {
      await pumpApp(tester, signedIn: false);
      await selectDay(tester, tomorrow);

      expect(find.byType(ListTile), findsNWidgets(15));
      expect(statusOf('10:00 - 11:00', 'Zauzet termin'), findsOneWidget);
    });
  });
}
