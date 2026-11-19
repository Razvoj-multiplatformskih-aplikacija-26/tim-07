import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/text/labels.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messages/messages.dart';

import 'support.dart';

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  /// Demo rezervacije su u odnosu na danas: sutra je potvrđena rezervacija
  /// terena 1 (Jovan Petrović, 18-20), za dva dana na čekanju na terenu 2
  /// (10-11), a za tri dana je blokada terena 1 od 8 do 12.
  final fieldOne = BackofficeDemoData.fields[0].name;
  final fieldTwo = BackofficeDemoData.fields[1].name;

  Future<BackofficeFakeReservationRepository> pumpCalendar(
    WidgetTester tester, {
    Size size = const Size(1600, 1000),
    SportsFieldRepository? fields,
    AppUser? owner,
  }) async {
    // Počinje se u širokom prozoru (stranica rezervacija se ne sužava ispod
    // 700), pa se prozor sužava tek na kalendaru.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final reservations = createBackofficeRepository(delay: Duration.zero);
    await tester.pumpWidget(
      BackofficeApp(
        repository: reservations,
        fieldRepository: fields ?? createBackofficeFieldRepository(),
        scheduleRepository: createBackofficeScheduleRepository(
          reservations: reservations,
        ),
        owner: owner ?? BackofficeDemoData.owner,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kalendar'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = size;
    await tester.pumpAndSettle();

    return reservations;
  }

  Future<void> next(WidgetTester tester, {String unit = 'Sledeći dan'}) async {
    await tester.tap(find.byTooltip(unit));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.textContaining(text);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
    await tester.tap(finder.first);
    await tester.pumpAndSettle();
  }

  group('stanja stranice', () {
    testWidgets('danas: kolona po terenu, legenda i dan u naslovu', (
      tester,
    ) async {
      await pumpCalendar(tester);

      expect(find.text(fieldOne), findsWidgets);
      expect(find.text(fieldTwo), findsWidgets);
      expect(
        find.text('${weekdayLong(today)}, ${formatDate(today)}'),
        findsOneWidget,
      );
      // Legenda objašnjava stanja i rečima.
      for (final label in [
        'Slobodno',
        'Na čekanju',
        'Potvrđena',
        'Blokirano',
      ]) {
        expect(find.text(label), findsWidgets);
      }
    });

    testWidgets('sutra: slobodni termini i potvrđena rezervacija sa imenom', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await next(tester);

      expect(find.text('Slobodno'), findsWidgets);
      expect(find.text('18:00 - 20:00'), findsOneWidget);
      expect(find.text('Potvrđena: Jovan Petrović'), findsOneWidget);
    });

    testWidgets('rezervacija na čekanju i blokada se razlikuju tekstom', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await next(tester);
      await next(tester);
      expect(find.textContaining('Na čekanju: '), findsOneWidget);

      await next(tester);
      expect(find.text('Blokirano: Održavanje terena'), findsOneWidget);
      expect(find.text('08:00 - 12:00'), findsOneWidget);
    });

    testWidgets('prošli dan prikazuje završenu rezervaciju', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Prethodni dan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Prethodni dan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Završena: '), findsOneWidget);
      expect(find.text('Prošlo'), findsWidgets);
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
      await pumpCalendar(tester, owner: stranger);

      expect(find.text('Nemate nijedan teren'), findsOneWidget);
    });

    testWidgets('teren se ne učita: razlog i „Pokušaj ponovo“', (tester) async {
      await pumpCalendar(tester, fields: FailingFields());

      expect(find.text('Kalendar nije učitan'), findsOneWidget);
      expect(find.text(serverUnreachableMessage), findsOneWidget);
      expect(find.text('Pokušaj ponovo'), findsOneWidget);
    });
  });

  group('dan i nedelja', () {
    testWidgets('nedeljni prikaz ima sedam dana i izbor terena', (
      tester,
    ) async {
      await pumpCalendar(tester);

      await tester.tap(find.text('Nedelja'));
      await tester.pumpAndSettle();

      final monday = CalendarBloc.weekStart(today);
      for (var i = 0; i < 7; i++) {
        final date = DateTime(monday.year, monday.month, monday.day + i);
        expect(
          find.text('${weekdayShort(date)} ${formatDayMonth(date)}'),
          findsOneWidget,
        );
      }
      expect(find.byType(DropdownButton<FieldId>), findsOneWidget);
    });

    testWidgets(
      'svih sedam dana stane u prozor od 1280 piksela, bez pomeranja',
      (tester) async {
        await pumpCalendar(tester, size: const Size(1280, 800));
        await tester.tap(find.text('Nedelja'));
        await tester.pumpAndSettle();

        final monday = CalendarBloc.weekStart(today);
        for (var i = 0; i < 7; i++) {
          final date = DateTime(monday.year, monday.month, monday.day + i);
          final header = find.text(
            '${weekdayShort(date)} ${formatDayMonth(date)}',
          );
          final right = tester.getTopRight(header).dx;
          expect(right, lessThanOrEqualTo(1280), reason: 'dan ${i + 1}');
          expect(tester.getTopLeft(header).dx, greaterThanOrEqualTo(0));
        }
      },
    );

    testWidgets(
      'u užem prozoru sedmi dan se dostiže prevlačenjem, a traka je vidljiva',
      (tester) async {
        await pumpCalendar(tester, size: const Size(900, 800));
        await tester.tap(find.text('Nedelja'));
        await tester.pumpAndSettle();
        final monday = CalendarBloc.weekStart(today);
        final sunday = DateTime(monday.year, monday.month, monday.day + 6);
        final last = find.text(
          '${weekdayShort(sunday)} ${formatDayMonth(sunday)}',
        );
        final before = tester.getTopLeft(last).dx;
        expect(
          before,
          greaterThan(560),
          reason: 'nedelja je izvan vidljive oblasti',
        );

        await tester.drag(
          find.text('Pon ${formatDayMonth(monday)}'),
          const Offset(-600, 0),
        );
        await tester.pumpAndSettle();

        expect(tester.getTopLeft(last).dx, lessThan(before));
        expect(find.byType(Scrollbar), findsWidgets);
      },
    );

    testWidgets('pomeranje po nedeljama menja opseg', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(find.text('Nedelja'));
      await tester.pumpAndSettle();
      final monday = CalendarBloc.weekStart(today);
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      expect(
        find.text('${formatDayMonth(monday)} - ${formatDate(sunday)}'),
        findsOneWidget,
      );

      await next(tester, unit: 'Sledeća nedelja');

      final following = DateTime(monday.year, monday.month, monday.day + 7);
      final end = DateTime(monday.year, monday.month, monday.day + 13);
      expect(
        find.text('${formatDayMonth(following)} - ${formatDate(end)}'),
        findsOneWidget,
      );
    });

    testWidgets('„Danas“ se vraća na današnji dan', (tester) async {
      await pumpCalendar(tester);
      await next(tester);
      await next(tester);

      await tester.tap(find.text('Danas'));
      await tester.pumpAndSettle();

      expect(
        find.text('${weekdayLong(today)}, ${formatDate(today)}'),
        findsOneWidget,
      );
    });

    testWidgets('izbor drugog terena u nedelji prikazuje njegove rezervacije', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await tester.tap(find.text('Nedelja'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<FieldId>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fieldTwo).last);
      await tester.pumpAndSettle();

      // Rezervacija na čekanju na terenu 2 je za dva dana, ako je u ovoj nedelji.
      final monday = CalendarBloc.weekStart(today);
      final inWeek =
          !day(2).isBefore(monday) &&
          day(2).isBefore(DateTime(monday.year, monday.month, monday.day + 7));
      expect(
        find.textContaining('Na čekanju: '),
        inWeek ? findsWidgets : findsNothing,
      );
    });
  });

  group('tastatura', () {
    testWidgets('strelice pomeraju dan, a T vraća na danas', (tester) async {
      await pumpCalendar(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.text('${weekdayLong(day(1))}, ${formatDate(day(1))}'),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        find.text('${weekdayLong(day(-1))}, ${formatDate(day(-1))}'),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      expect(
        find.text('${weekdayLong(today)}, ${formatDate(today)}'),
        findsOneWidget,
      );
    });

    testWidgets('rezervacija se bira fokusom i Enter-om', (tester) async {
      await pumpCalendar(tester);
      await next(tester);

      // Najbliži Focus iznad teksta je onaj koji pripada polju rezervacije.
      Focus.of(tester.element(find.text('Potvrđena: Jovan Petrović')))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Rezervacija #1'), findsOneWidget);
    });
  });

  group('detalji i akcije', () {
    testWidgets('klik na rezervaciju otvara detalje', (tester) async {
      await pumpCalendar(tester);
      await next(tester);
      expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);

      await tapText(tester, 'Potvrđena: Jovan Petrović');

      expect(find.text('Rezervacija #1'), findsOneWidget);
      expect(find.text('Otkaži'), findsOneWidget);
    });

    testWidgets('potvrda rezervacije na čekanju osvežava kalendar', (
      tester,
    ) async {
      await pumpCalendar(tester);
      await next(tester);
      await next(tester);

      await tapText(tester, 'Na čekanju: ');
      await tester.tap(find.text('Potvrdi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Na čekanju: '), findsNothing);
      expect(find.textContaining('Potvrđena: '), findsOneWidget);
    });

    testWidgets('otkazivanje oslobađa termin u kalendaru', (tester) async {
      await pumpCalendar(tester);
      await next(tester);

      await tapText(tester, 'Potvrđena: Jovan Petrović');
      await tester.tap(find.text('Otkaži'));
      await tester.pumpAndSettle();
      // Potvrda otkazivanja.
      await tester.tap(find.widgetWithText(FilledButton, 'Otkaži').last);
      await tester.pumpAndSettle();

      // Tile je nestao iz kalendara, a detalji kažu zašto.
      expect(find.text('Potvrđena: Jovan Petrović'), findsNothing);
      expect(find.text('Otkazana'), findsOneWidget);
    });

    testWidgets('u uskom prozoru detalji zamenjuju kalendar', (tester) async {
      await pumpCalendar(tester, size: const Size(500, 900));
      await next(tester);

      await tapText(tester, 'Potvrđena: Jovan Petrović');
      expect(find.text('Nazad na kalendar'), findsOneWidget);
      expect(find.text('Rezervacija #1'), findsOneWidget);

      await tester.tap(find.text('Nazad na kalendar'));
      await tester.pumpAndSettle();
      expect(find.text('Nazad na kalendar'), findsNothing);
      expect(find.text('Potvrđena: Jovan Petrović'), findsOneWidget);
    });

    testWidgets('uski prozor slaže kolone jednu ispod druge bez prelivanja', (
      tester,
    ) async {
      await pumpCalendar(tester, size: const Size(420, 800));

      expect(tester.takeException(), isNull);
      expect(find.text(fieldOne), findsWidgets);
      await tester.dragUntilVisible(
        find.text(fieldTwo),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text(fieldTwo), findsWidgets);
    });
  });
}
