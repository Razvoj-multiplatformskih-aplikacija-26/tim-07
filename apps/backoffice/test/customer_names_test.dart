import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Korisnik kakvog server šalje uz rezervaciju: ID koji ne postoji u demo podacima.
final marija = AppUser(
  id: const UserId(41),
  firstName: 'Marija',
  lastName: 'Marković',
  email: 'marija@example.com',
  phoneNumber: '0645555555',
  dateOfBirth: DateTime.utc(1970),
  role: UserRole.user,
  createdAt: DateTime.utc(2026),
);

void main() {
  final tomorrow = DateUtils.dateOnly(DateTime.now())
      .add(const Duration(days: 3));

  Reservation reservation(int id, int userId, {AppUser? customer}) =>
      Reservation(
        id: ReservationId(id),
        fieldId: const FieldId(1),
        userId: UserId(userId),
        startTime: tomorrow.add(Duration(hours: 8 + id)),
        endTime: tomorrow.add(Duration(hours: 9 + id)),
        totalPrice: 3000,
        status: ReservationStatus.confirmed,
        createdAt: tomorrow,
        customer: customer,
      );

  Future<void> pumpApp(
    WidgetTester tester,
    List<Reservation> reservations,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final source = BackofficeFakeReservationRepository(
      FakeReservationRepository(
        reservations: reservations,
        fields: BackofficeDemoData.fields,
        users: BackofficeDemoData.users,
      ),
      delay: Duration.zero,
    );
    await tester.pumpWidget(
      BackofficeApp(
        repository: source,
        fieldRepository: createBackofficeFieldRepository(),
        scheduleRepository: createBackofficeScheduleRepository(
          reservations: source,
        ),
        owner: BackofficeDemoData.owner,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tabela pokazuje ime korisnika koje je stiglo uz rezervaciju', (
    tester,
  ) async {
    await pumpApp(tester, [reservation(1, 41, customer: marija)]);

    expect(find.text('Marija Marković'), findsOneWidget);
  });

  testWidgets('detalji pokazuju email i telefon korisnika sa rezervacije', (
    tester,
  ) async {
    await pumpApp(tester, [reservation(1, 41, customer: marija)]);

    await tester.tap(find.text('#1'));
    await tester.pumpAndSettle();

    expect(find.text('Marija Marković'), findsWidgets);
    expect(find.text('marija@example.com'), findsOneWidget);
    expect(find.text('0645555555'), findsOneWidget);
  });

  testWidgets(
    'korisnik sa ID-jem iz demo podataka ne dobija demo ime kada stigne pravi',
    (tester) async {
      // Demo korisnik 1 je „Jovan Petrović“; server kaže da je rezervisala Marija.
      await pumpApp(tester, [reservation(1, 1, customer: marija)]);

      expect(find.text('Marija Marković'), findsOneWidget);
      expect(find.text('Jovan Petrović'), findsNothing);
    },
  );

  testWidgets(
    'bez podataka o korisniku piše samo broj, bez izmišljenog imena',
    (tester) async {
      await pumpApp(tester, [reservation(1, 777)]);

      expect(find.text('Korisnik #777'), findsOneWidget);
    },
  );

  testWidgets('promena stanja ne gubi ime korisnika', (tester) async {
    await pumpApp(tester, [
      reservation(
        1,
        41,
        customer: marija,
      ).copyWith(status: ReservationStatus.pending),
    ]);

    await tester.tap(find.text('#1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potvrdi'));
    await tester.pumpAndSettle();

    expect(find.text('Marija Marković'), findsWidgets);
  });
}
