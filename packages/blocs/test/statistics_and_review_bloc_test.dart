import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

AppUser _user(int id, UserRole role) => AppUser(
  id: UserId(id),
  firstName: 'Ime',
  lastName: role.name,
  email: '${role.name}@terenzo.rs',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026),
);

SportsField _field(int id, int ownerId, {ApprovalStatus approval = ApprovalStatus.approved}) => SportsField(
  id: FieldId(id),
  ownerId: UserId(ownerId),
  name: 'Teren $id',
  description: '',
  sport: SportType.football,
  address: 'Ulica 1',
  city: 'Beograd',
  pricePerHour: 3000,
  contactPhone: '0601234567',
  confirmationMode: ConfirmationMode.manual,
  approvalStatus: approval,
);

void main() {
  final owner = _user(10, UserRole.owner);
  final admin = _user(1, UserRole.admin);

  group('StatisticsBloc', () {
    late StatisticsBloc bloc;

    setUp(() {
      final fields = FakeSportsFieldRepository(fields: [_field(1, 10), _field(2, 99)]);
      final schedules = FakeFieldScheduleRepository(
        schedules: [
          for (final day in WeekDay.values)
            FieldSchedule(
              fieldId: const FieldId(1),
              dayOfWeek: day,
              opensAt: const TimeOfDay(hour: 8, minute: 0),
              closesAt: const TimeOfDay(hour: 22, minute: 0),
            ),
        ],
      );
      bloc = StatisticsBloc(
        repository: LocalStatisticsRepository(
          fields: fields,
          schedules: schedules,
          reservations: FakeReservationRepository(),
          viewer: owner,
        ),
        viewer: owner,
        clock: () => DateTime(2030, 6, 5),
      );
    });

    tearDown(() => bloc.close());

    test('vlasnik dobija samo svoje terene za tekuću nedelju', () async {
      bloc.add(const StatisticsStarted());
      final state = (await bloc.stream.firstWhere((s) => s is StatisticsLoaded)) as StatisticsLoaded;

      expect(state.report.fields.map((f) => f.fieldId), [const FieldId(1)]);
      expect(state.period.from, DateTime(2030, 6, 3));
      expect(state.report.availableMinutes, 7 * 14 * 60);
    });

    test('mesec i pomeranje perioda', () async {
      bloc.add(const StatisticsPeriodKindChanged(StatsPeriodKind.month));
      await bloc.stream.firstWhere((s) => s is StatisticsLoaded);
      bloc.add(const StatisticsPeriodMoved(1));
      final state = (await bloc.stream.firstWhere((s) => s is StatisticsLoaded)) as StatisticsLoaded;

      expect((state.period.from, state.period.to), (DateTime(2030, 7), DateTime(2030, 8)));
    });
  });

  group('FieldReviewBloc', () {
    test('administrator odobrava, a vlasnik ne može da odluči', () async {
      final fields = FakeSportsFieldRepository(fields: [_field(5, 10, approval: ApprovalStatus.pending)]);
      final byOwner = FieldReviewBloc(fields: fields, reviewer: owner)..add(const FieldReviewStarted());
      await byOwner.stream.firstWhere((s) => s is FieldReviewLoaded);
      byOwner.add(const FieldReviewDecided(FieldId(5), ApprovalStatus.approved));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((await fields.getFieldById(const FieldId(5)))!.approvalStatus, ApprovalStatus.pending);
      await byOwner.close();

      final byAdmin = FieldReviewBloc(fields: fields, reviewer: admin)..add(const FieldReviewStarted());
      await byAdmin.stream.firstWhere((s) => s is FieldReviewLoaded);
      byAdmin.add(const FieldReviewDecided(FieldId(5), ApprovalStatus.approved));
      final state = (await byAdmin.stream.firstWhere((s) => s is FieldReviewLoaded && s.message != null))
          as FieldReviewLoaded;
      await byAdmin.close();

      expect(state.waiting, isEmpty);
      expect((await fields.getFieldById(const FieldId(5)))!.approvalStatus, ApprovalStatus.approved);
    });
  });
}
