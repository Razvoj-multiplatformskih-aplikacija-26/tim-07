import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/selection/reservation_selection_bloc.dart';
import 'package:backoffice/widgets/reservations_table.dart';
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

  Future<void> pumpTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    selection = ReservationSelectionBloc();
    addTearDown(selection.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: selection,
            child: ReservationsTable(reservations: reservations),
          ),
        ),
      ),
    );
  }

  DataTable table(WidgetTester tester) =>
      tester.widget<DataTable>(find.byType(DataTable));

  testWidgets('Tabela ima sve kolone i po jedan red za svaku rezervaciju',
      (tester) async {
    await pumpTable(tester);

    for (final column in ['ID', 'Teren', 'Korisnik', 'Datum', 'Vreme', 'Status']) {
      expect(find.text(column), findsOneWidget);
    }

    expect(table(tester).rows.length, reservations.length);
  });

  testWidgets('Redovi su sortirani po pocetku termina', (tester) async {
    await pumpTable(tester);

    final rows = table(tester).rows;
    final firstKey = rows.first.key! as ValueKey<int>;

    final earliest = [...reservations]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    expect(firstKey.value, earliest.first.id.value);
  });

  testWidgets('Klik na red bira i oznacava rezervaciju', (tester) async {
    await pumpTable(tester);

    expect(table(tester).rows.any((row) => row.selected), isFalse);

    await tester.tap(find.text('#4'));
    await tester.pumpAndSettle();

    expect(selection.state.selectedId, const ReservationId(4));

    final selectedRows = table(tester).rows.where((row) => row.selected);
    expect(selectedRows.length, 1);
    expect((selectedRows.single.key! as ValueKey<int>).value, 4);
  });
}
