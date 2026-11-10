@Tags(['db'])
library;

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;
  late MySqlSportsFieldRepository fields;
  late MySqlReservationRepository reservations;
  final reviewedAt = DateTime.utc(2030, 6, 3, 8);

  setUp(() async {
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    await testDb!.migrate();
    await insertFixtures(testDb!.database);
    fields = MySqlSportsFieldRepository(testDb!.database, clock: () => reviewedAt);
    reservations = MySqlReservationRepository(testDb!.database, clock: () => DateTime(2030, 6, 3, 10));
  });

  tearDown(() async => testDb?.dispose());

  Future<SportsField> newField() => fields.createField(
        ownerId: const UserId(3),
        name: 'Padel Centar',
        description: 'Dva terena',
        sport: SportType.padel,
        address: 'Ulica 9',
        city: 'Beograd',
        pricePerHour: 2800,
        contactPhone: '064',
        confirmationMode: ConfirmationMode.manual,
      );

  Future<Reservation> reserve(FieldId fieldId) => reservations.createReservation(
        fieldId: fieldId,
        userId: const UserId(1),
        startTime: DateTime(2030, 6, 4, 18),
        endTime: DateTime(2030, 6, 4, 19),
      );

  Future<void> openEveryDay(FieldId fieldId) => MySqlFieldScheduleRepository(testDb!.database)
      .replaceSchedules(fieldId, [
        for (final day in WeekDay.values)
          FieldSchedule(
            fieldId: fieldId,
            dayOfWeek: day,
            opensAt: const TimeOfDay(hour: 8, minute: 0),
            closesAt: const TimeOfDay(hour: 23, minute: 0),
          ),
      ]);

  test('novi teren ulazi kao „na čekanju“ i nije u javnom katalogu', () async {
    if (testDb == null) return;
    final created = await newField();

    expect(created.approvalStatus, ApprovalStatus.pending);
    expect((await fields.getPublicFields()).map((f) => f.id), isNot(contains(created.id)));
    expect((await fields.getFieldsAwaitingApproval()).map((f) => f.name), ['Novi', 'Padel Centar']);
  });

  test('neodobren teren ne može da se rezerviše, odobren može', () async {
    if (testDb == null) return;
    final created = await newField();
    await openEveryDay(created.id);

    await expectLater(
      reserve(created.id),
      throwsA(isA<ReservationRuleViolation>().having((e) => e.error, 'error', isA<FieldUnavailable>())),
    );

    await fields.reviewField(fieldId: created.id, reviewerId: const UserId(4), decision: ApprovalStatus.approved);

    expect((await fields.getPublicFields()).map((f) => f.id), contains(created.id));
    expect((await reserve(created.id)).fieldId, created.id);
  });

  test('odbijanje čuva razlog, ko je i kada pregledao', () async {
    if (testDb == null) return;
    final created = await newField();

    final rejected = await fields.reviewField(
      fieldId: created.id,
      reviewerId: const UserId(4),
      decision: ApprovalStatus.rejected,
      reason: 'Nedostaju fotografije',
    );

    expect(rejected.approvalStatus, ApprovalStatus.rejected);
    expect(rejected.rejectionReason, 'Nedostaju fotografije');
    final row = await testDb!.database
        .query('SELECT reviewed_by, reviewed_at FROM sports_fields WHERE id = ?', [created.id.value]);
    expect(row.first[0], 4);
    expect(row.first[1], reviewedAt);
  });

  test('vlasnik izmeni odbijen teren: teren ponovo čeka odobrenje', () async {
    if (testDb == null) return;
    final created = await newField();
    final rejected = await fields.reviewField(
      fieldId: created.id,
      reviewerId: const UserId(4),
      decision: ApprovalStatus.rejected,
      reason: 'Nedostaju fotografije',
    );

    final edited = await fields.updateField(rejected.copyWith(imageUrls: const ['padel.jpg']));

    expect(edited.approvalStatus, ApprovalStatus.pending);
    expect((await fields.getFieldsAwaitingApproval()).map((f) => f.id), contains(created.id));
  });

  test('izmena ne može da odobri teren mimo administratora', () async {
    if (testDb == null) return;
    final created = await newField();

    final edited = await fields.updateField(created.copyWith(approvalStatus: ApprovalStatus.approved));

    expect(edited.approvalStatus, ApprovalStatus.pending);
  });

  test('nedozvoljen prelaz stanja odobrenosti se odbija', () async {
    if (testDb == null) return;

    await expectLater(
      fields.reviewField(fieldId: const FieldId(1), reviewerId: const UserId(4), decision: ApprovalStatus.approved),
      throwsA(isA<ApprovalTransitionNotAllowed>()),
    );
    await expectLater(
      fields.reviewField(fieldId: const FieldId(3), reviewerId: const UserId(4), decision: ApprovalStatus.pending),
      throwsA(isA<ApprovalTransitionNotAllowed>()),
    );
    await expectLater(
      fields.reviewField(fieldId: const FieldId(99), reviewerId: const UserId(4), decision: ApprovalStatus.approved),
      throwsA(isA<EntityNotFound>()),
    );
  });

  test('dva istovremena odobravanja istog terena: prolazi jedno', () async {
    if (testDb == null) return;
    final created = await newField();

    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        fields
            .reviewField(fieldId: created.id, reviewerId: const UserId(4), decision: ApprovalStatus.approved)
            .then<Object>((f) => f, onError: (Object e) => e),
    ]);

    expect(results.whereType<SportsField>(), hasLength(1));
    expect(results.whereType<ApprovalTransitionNotAllowed>(), hasLength(1));
    expect((await fields.getFieldById(created.id))!.approvalStatus, ApprovalStatus.approved);
  });
}
