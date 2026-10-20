import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/selection/reservation_selection_bloc.dart';
import 'package:backoffice/widgets/reservation_details_panel.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ReservationSelectionBloc selection;
  late List<Reservation> reservations;

  setUp(() {
    reservations = BackofficeDemoData.createReservations(
      now: DateTime(2026, 10, 20, 12),
    );
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    selection = ReservationSelectionBloc();
    addTearDown(selection.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: selection,
            child: ReservationDetailsPanel(reservations: reservations),
          ),
        ),
      ),
    );
  }

  Future<void> select(WidgetTester tester, int id) async {
    selection.add(ReservationSelected(ReservationId(id)));
    await tester.pumpAndSettle();
  }

  testWidgets('Bez izbora prikazuje uputstvo', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
  });

  testWidgets('Prikazuje teren, korisnika, termin i status', (tester) async {
    await pumpPanel(tester);
    await select(tester, 2);

    expect(find.text('Rezervacija #2'), findsOneWidget);
    expect(find.text('Tenis Centar'), findsOneWidget);
    expect(find.text('Ana Jovanović'), findsOneWidget);
    expect(find.text('ana.jovanovic@example.com'), findsOneWidget);
    expect(find.text('16:00 - 17:00'), findsOneWidget);
    expect(find.text('Na čekanju'), findsOneWidget);
  });

  testWidgets('Rezervacija na cekanju nudi potvrdu i odbijanje',
      (tester) async {
    await pumpPanel(tester);
    await select(tester, 2);

    expect(find.widgetWithText(Chip, 'Potvrdi'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Odbij'), findsOneWidget);
  });

  testWidgets('Zavrsena rezervacija nema dostupnih akcija', (tester) async {
    await pumpPanel(tester);
    await select(tester, 6);

    expect(find.text('Nema dostupnih akcija za ovaj status.'), findsOneWidget);
  });

  testWidgets('Panel se menja kada se promeni izbor', (tester) async {
    await pumpPanel(tester);
    await select(tester, 2);
    await select(tester, 3);

    expect(find.text('Rezervacija #3'), findsOneWidget);
    expect(find.text('Rezervacija #2'), findsNothing);
    expect(find.text('Basket Park'), findsOneWidget);
  });

  testWidgets('Dugme za zatvaranje uklanja izbor', (tester) async {
    await pumpPanel(tester);
    await select(tester, 2);

    await tester.tap(find.byTooltip('Zatvori detalje'));
    await tester.pumpAndSettle();

    expect(selection.state.selectedId, isNull);
    expect(find.text('Izaberite rezervaciju u tabeli.'), findsOneWidget);
  });
}
