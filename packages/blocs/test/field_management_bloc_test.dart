import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final owner = AppUser(
    id: const UserId(10),
    firstName: 'Vlada',
    lastName: 'Vlasnik',
    email: 'vlada@terenzo.rs',
    phoneNumber: '060',
    dateOfBirth: DateTime(1985),
    role: UserRole.owner,
    createdAt: DateTime(2026),
  );

  SportsField field(int id, String name, {int ownerId = 10}) => SportsField(
    id: FieldId(id),
    ownerId: UserId(ownerId),
    name: name,
    description: '',
    sport: SportType.football,
    address: 'Ulica 1',
    city: 'Beograd',
    pricePerHour: 3000,
    contactPhone: '0601234567',
    confirmationMode: ConfirmationMode.manual,
  );

  const draft = FieldDraft(
    name: 'Novi teren',
    description: 'Opis',
    sport: SportType.tennis,
    address: 'Ulica 2',
    city: 'Novi Sad',
    pricePerHour: 2000,
    contactPhone: '0611234567',
    confirmationMode: ConfirmationMode.automatic,
  );

  late FakeSportsFieldRepository fields;
  late FakeFieldScheduleRepository schedules;
  late FieldManagementBloc bloc;

  setUp(() {
    fields = FakeSportsFieldRepository(fields: [field(1, 'Arena'), field(2, 'Tuđi', ownerId: 99)]);
    schedules = FakeFieldScheduleRepository(
      schedules: [
        const FieldSchedule(
          fieldId: FieldId(1),
          dayOfWeek: WeekDay.monday,
          opensAt: TimeOfDay(hour: 8, minute: 0),
          closesAt: TimeOfDay(hour: 22, minute: 0),
        ),
      ],
    );
    bloc = FieldManagementBloc(fields: fields, schedules: schedules, owner: owner);
  });

  tearDown(() => bloc.close());

  Future<FieldManagementLoaded> loaded() async =>
      (await bloc.stream.firstWhere((s) => s is FieldManagementLoaded && !s.busy)) as FieldManagementLoaded;

  test('vlasnik vidi samo svoje terene i radno vreme izabranog', () async {
    bloc.add(const FieldManagementStarted());
    final state = await loaded();

    expect(state.fields.map((f) => f.name), ['Arena']);
    expect(state.schedules.single.dayOfWeek, WeekDay.monday);
  });

  test('vlasnik bez terena dobija prazan prikaz', () async {
    bloc = FieldManagementBloc(
      fields: FakeSportsFieldRepository(),
      schedules: schedules,
      owner: owner,
    );
    bloc.add(const FieldManagementStarted());

    expect(await bloc.stream.firstWhere((s) => s is! FieldManagementLoading), isA<FieldManagementEmpty>());
  });

  test('novi teren se dodaje i postaje izabran, čeka odobrenje', () async {
    bloc.add(const FieldManagementStarted());
    await loaded();

    bloc.add(const FieldSaveRequested(draft));
    final state = (await bloc.stream.firstWhere((s) => s is FieldManagementLoaded && s.success)) as FieldManagementLoaded;

    expect(state.field.name, 'Novi teren');
    expect(state.field.ownerId, owner.id);
    expect(state.fields, hasLength(2));
  });

  test('izmena menja cenu postojećeg terena', () async {
    bloc.add(const FieldManagementStarted());
    final first = await loaded();

    bloc.add(FieldSaveRequested(
      FieldDraft.of(first.field).copyWithPrice(4500),
      fieldId: first.field.id,
    ));
    final state = (await bloc.stream.firstWhere((s) => s is FieldManagementLoaded && s.success)) as FieldManagementLoaded;

    expect(state.field.pricePerHour, 4500);
  });

  test('neispravni podaci i neispravno radno vreme se ne šalju', () async {
    bloc.add(const FieldManagementStarted());
    await loaded();

    expect(FieldDraft.of(field(3, ' ')).errors, contains(FieldDataError.emptyName));
    bloc.add(const FieldScheduleSaveRequested([
      FieldSchedule(
        fieldId: FieldId(1),
        dayOfWeek: WeekDay.monday,
        opensAt: TimeOfDay(hour: 22, minute: 0),
        closesAt: TimeOfDay(hour: 8, minute: 0),
      ),
    ]));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect((await schedules.getSchedules(const FieldId(1))).single.opensAt.hour, 8);
  });

  test('radno vreme se čuva za izabrani teren', () async {
    bloc.add(const FieldManagementStarted());
    await loaded();

    bloc.add(const FieldScheduleSaveRequested([
      FieldSchedule(
        fieldId: FieldId(1),
        dayOfWeek: WeekDay.saturday,
        opensAt: TimeOfDay(hour: 9, minute: 30),
        closesAt: TimeOfDay(hour: 18, minute: 0),
      ),
    ]));
    final state = (await bloc.stream.firstWhere((s) => s is FieldManagementLoaded && s.success)) as FieldManagementLoaded;

    expect(state.schedules.single.dayOfWeek, WeekDay.saturday);
    expect(state.message, 'Radno vreme je sačuvano.');
  });
}

extension on FieldDraft {
  FieldDraft copyWithPrice(int price) => FieldDraft(
    name: name,
    description: description,
    sport: sport,
    address: address,
    city: city,
    pricePerHour: price,
    contactPhone: contactPhone,
    confirmationMode: confirmationMode,
    isActive: isActive,
  );
}
