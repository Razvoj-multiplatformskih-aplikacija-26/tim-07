import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

// Četvrtak 19. 11. 2026. u podne; rezervacija je u petak 20. 11. u 15 časova.
final now = DateTime(2026, 11, 19, 12);

AppUser person() => AppUser(
  id: const UserId(10),
  firstName: 'Petar',
  lastName: 'Vlasnik',
  email: 'vlasnik@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: UserRole.owner,
  createdAt: DateTime(2026),
);

SportsField field() => SportsField(
  id: const FieldId(3),
  ownerId: const UserId(10),
  name: 'Teren 3',
  description: 'Opis',
  sport: SportType.tennis,
  address: 'Ulica 1',
  city: 'Beograd',
  pricePerHour: 2000,
  contactPhone: '060',
  confirmationMode: ConfirmationMode.manual,
);

List<FieldSchedule> week({required int opens, required int closes}) => [
  for (final day in WeekDay.values)
    FieldSchedule(
      fieldId: const FieldId(3),
      dayOfWeek: day,
      opensAt: TimeOfDay(hour: opens, minute: 0),
      closesAt: TimeOfDay(hour: closes, minute: 0),
    ),
];

Reservation reservation(ReservationStatus status) => Reservation(
  id: const ReservationId(1),
  fieldId: const FieldId(3),
  userId: const UserId(1),
  startTime: DateTime(2026, 11, 20, 15),
  endTime: DateTime(2026, 11, 20, 16),
  totalPrice: 2000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  late FakeReservationRepository store;
  late FakeFieldScheduleRepository schedules;
  late FieldManagementBloc bloc;

  void build(ReservationStatus status) {
    store = FakeReservationRepository(
      clock: () => now,
      reservations: [reservation(status)],
    );
    schedules = FakeFieldScheduleRepository(
      reservations: store,
      clock: () => now,
      schedules: week(opens: 8, closes: 22),
    );
    bloc = FieldManagementBloc(
      fields: FakeSportsFieldRepository(fields: [field()]),
      schedules: schedules,
      owner: person(),
    );
  }

  Future<FieldManagementLoaded> loaded() async {
    final next = bloc.stream.firstWhere((s) => s is FieldManagementLoaded);
    bloc.add(const FieldManagementStarted());
    return await next as FieldManagementLoaded;
  }

  Future<FieldManagementLoaded> save(List<FieldSchedule> schedules) async {
    final next = bloc.stream.firstWhere(
      (s) => s is FieldManagementLoaded && s.message != null && !s.busy,
    );
    bloc.add(FieldScheduleSaveRequested(schedules));
    return await next as FieldManagementLoaded;
  }

  tearDown(() => bloc.close());

  test('skraćenje radnog vremena preko potvrđene rezervacije: poruka, ništa se ne menja', () async {
    build(ReservationStatus.confirmed);
    await loaded();

    final state = await save(week(opens: 8, closes: 14));

    expect(state.success, isFalse);
    expect(state.message, contains('jednu postojeću rezervaciju'));
    expect(state.message, contains('20.11.2026. u 15:00'));
    // Radno vreme je ostalo staro.
    expect(state.schedules.every((s) => s.closesAt.hour == 22), isTrue);
  });

  test('isto za rezervaciju na čekanju', () async {
    build(ReservationStatus.pending);
    await loaded();

    final state = await save(week(opens: 8, closes: 14));

    expect(state.success, isFalse);
    expect(state.message, contains('postojeću rezervaciju'));
  });

  test('promena koja obuhvata rezervaciju se čuva', () async {
    build(ReservationStatus.confirmed);
    await loaded();

    final state = await save(week(opens: 10, closes: 18));

    expect(state.success, isTrue);
    expect(state.message, 'Radno vreme je sačuvano.');
    expect(state.schedules.every((s) => s.opensAt.hour == 10), isTrue);
  });

  test('posle otkazivanja rezervacije isto skraćenje prolazi', () async {
    build(ReservationStatus.confirmed);
    await loaded();
    await save(week(opens: 8, closes: 14)); // odbijeno

    await store.cancelReservation(const ReservationId(1));
    final state = await save(week(opens: 8, closes: 14));

    expect(state.success, isTrue);
    expect(state.schedules.every((s) => s.closesAt.hour == 14), isTrue);
  });
}
