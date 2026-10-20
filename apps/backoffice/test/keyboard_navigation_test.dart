import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:backoffice/widgets/shortcut_hints.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BackofficeFakeReservationRepository repository;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    repository = createBackofficeRepository(delay: Duration.zero);

    await tester.pumpWidget(BackofficeApp(repository: repository));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<ReservationStatus?> statusOf(int id) async =>
      (await repository.getReservationById(ReservationId(id)))?.status;

  testWidgets('Prikazuje spisak precica', (tester) async {
    await pumpApp(tester);

    expect(find.byType(ShortcutHints), findsOneWidget);
    expect(find.text('potvrdi'), findsOneWidget);
  });

  testWidgets('Strelice menjaju izabrani red po redosledu u tabeli',
      (tester) async {
    await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Rezervacija #6'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Rezervacija #1'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(find.text('Rezervacija #6'), findsOneWidget);
  });

  testWidgets('Home i End biraju prvi i poslednji red', (tester) async {
    await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.end);
    expect(find.text('Rezervacija #7'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.home);
    expect(find.text('Rezervacija #6'), findsOneWidget);
  });

  testWidgets('Precica P potvrdjuje izabranu rezervaciju', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('#2'));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyP);

    expect(await statusOf(2), ReservationStatus.confirmed);
  });

  testWidgets('Precica O otvara dijalog, a Esc ga zatvara bez promene',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('#4'));
    await tester.pumpAndSettle();
    await press(tester, LogicalKeyboardKey.keyO);

    expect(find.byType(AlertDialog), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);

    expect(find.byType(AlertDialog), findsNothing);
    expect(await statusOf(4), ReservationStatus.pending);
  });

  testWidgets('Enter vodi fokus na akcije, a Esc vraca fokus na tabelu',
      (tester) async {
    await pumpApp(tester);

    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(find.text('Rezervacija #4'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.enter);
    final focused = FocusManager.instance.primaryFocus;
    expect(focused?.debugLabel, 'Akcije rezervacije');

    await press(tester, LogicalKeyboardKey.escape);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'Tabela rezervacija',
    );
    expect(find.text('Rezervacija #4'), findsOneWidget);

    await press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
  });
}
