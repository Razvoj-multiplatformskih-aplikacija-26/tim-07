import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('statistika prikazuje terene vlasnika i menja period', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(backofficeApp(createBackofficeRepository(delay: Duration.zero)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Statistika'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Realizovane rezervacije'), findsOneWidget);

    await tester.tap(find.text('Mesec'));
    await tester.pumpAndSettle();
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('vlasnik ne vidi odobravanje terena', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(backofficeApp(createBackofficeRepository(delay: Duration.zero)));
    await tester.pumpAndSettle();

    expect(find.text('Odobravanje'), findsNothing);
  });

  testWidgets('administrator odobrava teren koji čeka', (tester) async {
    bigScreen(tester);
    final admin = AppUser(
      id: const UserId(900),
      firstName: 'Admin',
      lastName: 'Admin',
      email: 'admin@terenzo.rs',
      phoneNumber: '060',
      dateOfBirth: DateTime(1980),
      role: UserRole.admin,
      createdAt: DateTime(2026),
    );
    final reservations = createBackofficeRepository(delay: Duration.zero);
    final fields = FakeSportsFieldRepository(
      fields: [
        SportsField(
          id: const FieldId(50),
          ownerId: BackofficeDemoData.owner.id,
          name: 'Novi padel',
          description: '',
          sport: SportType.padel,
          address: 'Ulica 1',
          city: 'Beograd',
          pricePerHour: 2500,
          contactPhone: '0601234567',
          confirmationMode: ConfirmationMode.manual,
          approvalStatus: ApprovalStatus.pending,
        ),
      ],
    );
    await tester.pumpWidget(
      BackofficeApp(
        repository: reservations,
        fieldRepository: fields,
        scheduleRepository: createBackofficeScheduleRepository(reservations: reservations),
        owner: admin,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Odobravanje'));
    await tester.pumpAndSettle();
    expect(find.text('Novi padel'), findsOneWidget);

    await tester.tap(find.text('Odobri'));
    await tester.pumpAndSettle();

    expect(find.text('Nema terena koji čekaju odobrenje.'), findsOneWidget);
    expect((await fields.getFieldById(const FieldId(50)))!.approvalStatus, ApprovalStatus.approved);
  });
}
