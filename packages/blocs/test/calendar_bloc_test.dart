import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

const ownerId = UserId(100);
const field3 = FieldId(3);
const field4 = FieldId(4);
const foreignField = FieldId(9);

// Četvrtak 19. 11. 2026. u podne; petak je 20. 11., ponedeljak nedelje 16. 11.
final now = DateTime(2026, 11, 19, 12);

AppUser person(int id, UserRole role) => AppUser(
  id: UserId(id),
  firstName: 'Ime',
  lastName: 'Prezime',
  email: 'korisnik$id@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026, 1, 1),
);

final owner = person(100, UserRole.owner);

SportsField field(int id, {UserId by = ownerId}) => SportsField(
  id: FieldId(id),
  ownerId: by,
  name: 'Teren $id',
  description: 'Opis',
  sport: SportType.padel,
  address: 'A $id',
  city: 'Beograd',
  pricePerHour: 3000,
  contactPhone: '060',
  confirmationMode: ConfirmationMode.automatic,
);

DateTime friday(int hour) => DateTime(2026, 11, 20, hour);

Reservation reservation(
  int id,
  FieldId onField,
  int hour, [
  ReservationStatus status = ReservationStatus.confirmed,
]) => Reservation(
  id: ReservationId(id),
  fieldId: onField,
  userId: const UserId(1),
  startTime: friday(hour),
  endTime: friday(hour + 1),
  totalPrice: 3000,
  status: status,
  createdAt: DateTime(2026, 11, 1),
);

FieldSchedule open(FieldId onField, WeekDay day) => FieldSchedule(
  fieldId: onField,
  dayOfWeek: day,
  opensAt: const TimeOfDay(hour: 8, minute: 0),
  closesAt: const TimeOfDay(hour: 12, minute: 0),
);

/// Čita rezervacije pravom repozitorijumu, ali može da zakasni ili da pukne.
final class _Reservations implements ReservationRepository {
  final ReservationRepository inner;
  Object? error;

  /// Prvi poziv čeka na ovo, pa drugi može da ga pretekne.
  Completer<void>? gate;
  int reads = 0;

  _Reservations(this.inner);

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    reads++;
    final pending = gate;
    if (pending != null) {
      gate = null;
      await pending.future;
    }
    final failure = error;
    if (failure != null) throw failure;
    return inner.getReservationsByField(fieldId);
  }

  @override
  Future<List<Reservation>> getReservations() => inner.getReservations();

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) =>
      inner.getReservationsByUser(userId);

  @override
  Future<Reservation?> getReservationById(ReservationId id) =>
      inner.getReservationById(id);

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) => inner.createReservation(
    fieldId: fieldId,
    userId: userId,
    startTime: startTime,
    endTime: endTime,
  );

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) => inner.updateReservationStatus(
    reservationId: reservationId,
    status: status,
  );

  @override
  Future<Reservation> checkIn(ReservationId reservationId) =>
      inner.checkIn(reservationId);

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) =>
      inner.cancelReservation(reservationId);
}

/// Spisak terena koji može da pukne.
final class _Fields implements SportsFieldRepository {
  final SportsFieldRepository inner;
  Object? error;

  _Fields(this.inner);

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async {
    final failure = error;
    if (failure != null) throw failure;
    return inner.getFieldsByOwner(ownerId);
  }

  @override
  Future<List<SportsField>> getFields() => inner.getFields();

  @override
  Future<List<SportsField>> getPublicFields() => inner.getPublicFields();

  @override
  Future<SportsField?> getFieldById(FieldId id) => inner.getFieldById(id);

  @override
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  }) => inner.createField(
    ownerId: ownerId,
    name: name,
    description: description,
    sport: sport,
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: confirmationMode,
  );

  @override
  Future<SportsField> updateField(SportsField field) =>
      inner.updateField(field);

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() =>
      inner.getFieldsAwaitingApproval();

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) => inner.reviewField(
    fieldId: fieldId,
    reviewerId: reviewerId,
    decision: decision,
    reason: reason,
  );
}

/// Sledeće stanje koje nije učitavanje ni osvežavanje.
Future<CalendarState> settled(CalendarBloc bloc) => bloc.stream.firstWhere(
  (state) =>
      state is! CalendarLoading &&
      !(state is CalendarLoaded && state.refreshing),
);

/// Pošalje događaj i vrati stanje kada se učitavanje završi.
Future<CalendarLoaded> send(CalendarBloc bloc, CalendarEvent event) async {
  final next = settled(bloc);
  bloc.add(event);
  return await next as CalendarLoaded;
}

String describe(CalendarEntry entry) {
  final range = '${entry.startTime.hour}-${entry.endTime.hour}';
  return switch (entry) {
    CalendarFreeSlot(:final isPast) => isPast ? 'past $range' : 'free $range',
    CalendarReservation(:final status) => '${status.name} $range',
    CalendarBlock() => 'block $range',
  };
}

List<String> column(CalendarLoaded state, FieldId fieldId, [int index = 0]) => [
  for (final entry
      in state.days
          .where((day) => day.fieldId == fieldId)
          .toList()[index]
          .entries)
    describe(entry),
];

void main() {
  late FakeReservationRepository reservationStore;
  late FakeSportsFieldRepository fieldStore;
  late FakeFieldScheduleRepository scheduleStore;
  late _Reservations reservations;
  late _Fields fields;
  late CalendarBloc bloc;

  CalendarBloc create() => CalendarBloc(
    fields: fields,
    schedules: scheduleStore,
    reservations: reservations,
    owner: owner,
    clock: () => now,
  );

  setUp(() {
    reservationStore = FakeReservationRepository(
      clock: () => now,
      reservations: [
        reservation(1, field3, 11),
        reservation(2, field4, 9, ReservationStatus.pending),
        reservation(3, foreignField, 8),
      ],
    );
    fieldStore = FakeSportsFieldRepository(
      fields: [
        field(3),
        field(4),
        field(9, by: const UserId(200)),
      ],
    );
    scheduleStore = FakeFieldScheduleRepository(
      reservations: reservationStore,
      clock: () => now,
      schedules: [
        for (final id in [field3, field4, foreignField])
          for (final day in [WeekDay.thursday, WeekDay.friday]) open(id, day),
      ],
      blockedPeriods: [
        BlockedPeriod(
          id: const BlockedPeriodId(1),
          fieldId: field3,
          startTime: friday(8),
          endTime: friday(10),
          reason: 'Održavanje',
        ),
      ],
    );
    reservations = _Reservations(reservationStore);
    fields = _Fields(fieldStore);
    bloc = create();
  });

  tearDown(() => bloc.close());

  group('početak', () {
    test(
      'prvo je učitavanje, pa današnji dan za sve terene vlasnika',
      () async {
        final states = <CalendarState>[];
        bloc.stream.listen(states.add);

        final loaded = await send(bloc, const CalendarStarted());

        expect(states.first, isA<CalendarLoading>());
        expect(loaded.view, CalendarView.day);
        expect(loaded.date, DateTime(2026, 11, 19));
        expect(loaded.rangeStart, DateTime(2026, 11, 19));
        expect(loaded.rangeEnd, DateTime(2026, 11, 20));
        expect(loaded.fields.map((f) => f.id), [field3, field4]);
        expect(loaded.days.map((d) => d.fieldId), [field3, field4]);
        expect(loaded.now, now);
        expect(loaded.refreshing, isFalse);
        expect(loaded.message, isNull);
      },
    );

    test('tuđi teren i tuđe rezervacije se ne vide', () async {
      final loaded = await send(bloc, const CalendarStarted());

      expect(loaded.days.any((d) => d.fieldId == foreignField), isFalse);
      expect(
        loaded.reservations.any((r) => r.fieldId == foreignField),
        isFalse,
      );
    });

    test('vlasnik bez terena dobija stanje bez terena', () async {
      await fieldStore.getFieldsByOwner(ownerId); // izvor je isti kao u ostalim
      final stranger = CalendarBloc(
        fields: fields,
        schedules: scheduleStore,
        reservations: reservations,
        owner: person(777, UserRole.owner),
        clock: () => now,
      );
      addTearDown(stranger.close);

      final next = settled(stranger);
      stranger.add(const CalendarStarted());

      expect(await next, isA<CalendarNoFields>());
    });

    test('greška pri učitavanju terena je stanje greške sa porukom', () async {
      fields.error = const ServerUnreachableException();

      final next = settled(bloc);
      bloc.add(const CalendarStarted());
      final state = await next;

      expect(state, isA<CalendarError>());
      expect(
        (state as CalendarError).message,
        describeError(const ServerUnreachableException()),
      );
    });

    test('„Pokušaj ponovo“ posle greške učitava kalendar', () async {
      fields.error = const ServerUnreachableException();
      final failed = settled(bloc);
      bloc.add(const CalendarStarted());
      await failed;

      fields.error = null;
      final loaded = await send(bloc, const CalendarRefreshed());

      expect(loaded.days, hasLength(2));
    });

    test('osvežavanje pre učitavanja ne radi ništa', () async {
      bloc.add(const CalendarRefreshed());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<CalendarLoading>());
      expect(reservations.reads, 0);
    });
  });

  group('dnevni prikaz', () {
    test(
      'kolona po terenu sa slobodnim, zauzetim i blokiranim terminima',
      () async {
        await send(bloc, const CalendarStarted());
        final loaded = await send(bloc, const CalendarMoved(1));

        expect(loaded.date, DateTime(2026, 11, 20));
        expect(column(loaded, field3), [
          'block 8-10',
          'free 10-11',
          'confirmed 11-12',
        ]);
        expect(column(loaded, field4), [
          'free 8-9',
          'pending 9-10',
          'free 10-11',
          'free 11-12',
        ]);
      },
    );

    test('današnji termini koji su počeli su prošli', () async {
      final loaded = await send(bloc, const CalendarStarted());

      // Sada je 12:00, a teren radi do 12:00: svi termini su počeli.
      expect(column(loaded, field3), everyElement(startsWith('past')));
    });

    test('izbor terena ne menja dnevni prikaz, ali pamti teren', () async {
      await send(bloc, const CalendarStarted());
      final loaded = await send(bloc, const CalendarFieldSelected(field4));

      expect(loaded.field.id, field4);
      expect(loaded.days.map((d) => d.fieldId), [field3, field4]);
    });
  });

  group('pomeranje', () {
    test('ekran odmah dobija novi dan uz „osvežava se“, pa podatke', () async {
      await send(bloc, const CalendarStarted());
      final states = <CalendarState>[];
      bloc.stream.listen(states.add);

      await send(bloc, const CalendarMoved(1));

      final pending = states.first as CalendarLoaded;
      expect(pending.refreshing, isTrue);
      expect(pending.date, DateTime(2026, 11, 20));
      expect(pending.days, isEmpty);
      final done = states.last as CalendarLoaded;
      expect(done.refreshing, isFalse);
      expect(done.days, isNotEmpty);
    });

    test('unazad i više koraka odjednom', () async {
      await send(bloc, const CalendarStarted());

      expect(
        (await send(bloc, const CalendarMoved(-1))).date,
        DateTime(2026, 11, 18),
      );
      expect(
        (await send(bloc, const CalendarMoved(3))).date,
        DateTime(2026, 11, 21),
      );
    });

    test('pomeranje za nula koraka ne učitava ništa', () async {
      await send(bloc, const CalendarStarted());
      final reads = reservations.reads;

      bloc.add(const CalendarMoved(0));
      await Future<void>.delayed(Duration.zero);

      expect(reservations.reads, reads);
    });

    test('„Danas“ vraća na današnji dan', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarMoved(5));

      final loaded = await send(bloc, const CalendarTodayRequested());

      expect(loaded.date, DateTime(2026, 11, 19));
    });

    test('izabrani datum se svodi na ponoć', () async {
      await send(bloc, const CalendarStarted());

      final loaded = await send(
        bloc,
        CalendarDateSelected(DateTime(2026, 12, 24, 17, 45)),
      );

      expect(loaded.date, DateTime(2026, 12, 24));
      expect(loaded.rangeStart, DateTime(2026, 12, 24));
    });

    test('prelazak preko kraja meseca i godine', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, CalendarDateSelected(DateTime(2026, 12, 31)));

      final loaded = await send(bloc, const CalendarMoved(1));

      expect(loaded.date, DateTime(2027));
    });

    test('pomeranje pre učitavanja ne radi ništa', () async {
      bloc.add(const CalendarMoved(1));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<CalendarLoading>());
    });
  });

  group('nedeljni prikaz', () {
    test('sedam dana jednog terena, od ponedeljka do nedelje', () async {
      await send(bloc, const CalendarStarted());

      final loaded = await send(
        bloc,
        const CalendarViewChanged(CalendarView.week),
      );

      expect(loaded.view, CalendarView.week);
      expect(loaded.rangeStart, DateTime(2026, 11, 16));
      expect(loaded.rangeEnd, DateTime(2026, 11, 23));
      expect(loaded.days, hasLength(7));
      expect(loaded.days.map((d) => d.fieldId).toSet(), {field3});
      expect(loaded.days.map((d) => d.date.day), [16, 17, 18, 19, 20, 21, 22]);
      // Ponedeljak i vikend nemaju radno vreme u ovom rasporedu.
      expect(loaded.days.map((d) => d.isOpen), [
        false,
        false,
        false,
        true,
        true,
        false,
        false,
      ]);
      expect(column(loaded, field3, 4), [
        'block 8-10',
        'free 10-11',
        'confirmed 11-12',
      ]);
    });

    test('pomeranje ide za nedelju dana', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarViewChanged(CalendarView.week));

      final next = await send(bloc, const CalendarMoved(1));
      final previous = await send(bloc, const CalendarMoved(-2));

      expect(next.rangeStart, DateTime(2026, 11, 23));
      expect(previous.rangeStart, DateTime(2026, 11, 9));
    });

    test('izbor drugog terena prikazuje njegovu nedelju', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarViewChanged(CalendarView.week));

      final loaded = await send(bloc, const CalendarFieldSelected(field4));

      expect(loaded.field.id, field4);
      expect(loaded.days.map((d) => d.fieldId).toSet(), {field4});
      expect(column(loaded, field4, 4)[1], 'pending 9-10');
    });

    test('tuđ i nepoznat teren se ne prihvata', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarViewChanged(CalendarView.week));
      final reads = reservations.reads;

      bloc.add(const CalendarFieldSelected(foreignField));
      bloc.add(const CalendarFieldSelected(FieldId(404)));
      await Future<void>.delayed(Duration.zero);

      expect((bloc.state as CalendarLoaded).field.id, field3);
      expect(reservations.reads, reads);
    });

    test('povratak na dnevni prikaz čuva izabrani dan', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarMoved(1));
      await send(bloc, const CalendarViewChanged(CalendarView.week));

      final loaded = await send(
        bloc,
        const CalendarViewChanged(CalendarView.day),
      );

      expect(loaded.date, DateTime(2026, 11, 20));
      expect(loaded.days, hasLength(2));
    });

    test('isti prikaz ponovo ne učitava ništa', () async {
      await send(bloc, const CalendarStarted());
      final reads = reservations.reads;

      bloc.add(const CalendarViewChanged(CalendarView.day));
      await Future<void>.delayed(Duration.zero);

      expect(reservations.reads, reads);
    });

    test('nedelja počinje u ponedeljak, i kada je izabrana nedelja', () {
      expect(
        CalendarBloc.weekStart(DateTime(2026, 11, 22)),
        DateTime(2026, 11, 16),
      );
      expect(
        CalendarBloc.weekStart(DateTime(2026, 11, 16)),
        DateTime(2026, 11, 16),
      );
      expect(
        CalendarBloc.weekStart(DateTime(2027, 1, 1)),
        DateTime(2026, 12, 28),
      );
    });
  });

  group('osvežavanje', () {
    test('zadržava podatke dok novi ne stignu, pa prikazuje promenu', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarMoved(1));
      final states = <CalendarState>[];
      bloc.stream.listen(states.add);

      // Vlasnik potvrđuje rezervaciju na čekanju i kalendar se osvežava.
      await reservationStore.updateReservationStatus(
        reservationId: const ReservationId(2),
        status: ReservationStatus.confirmed,
      );
      final loaded = await send(bloc, const CalendarRefreshed());

      final pending = states.first as CalendarLoaded;
      expect(pending.refreshing, isTrue);
      expect(pending.days, isNotEmpty);
      expect(column(loaded, field4)[1], 'confirmed 9-10');
    });

    test('otkazana rezervacija ostavlja slobodan termin', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarMoved(1));

      await reservationStore.cancelReservation(const ReservationId(1));
      final loaded = await send(bloc, const CalendarRefreshed());

      expect(column(loaded, field3).last, 'free 11-12');
    });

    test('nova blokada se vidi posle osvežavanja', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarMoved(1));

      await scheduleStore.addBlockedPeriod(
        BlockedPeriod(
          fieldId: field4,
          startTime: friday(10),
          endTime: friday(12),
        ),
      );
      final loaded = await send(bloc, const CalendarRefreshed());

      expect(column(loaded, field4), [
        'free 8-9',
        'pending 9-10',
        'block 10-12',
      ]);
    });
  });

  group('greške i zastareli odgovori', () {
    test('greška pri pomeranju zadržava novi opseg i javlja razlog', () async {
      await send(bloc, const CalendarStarted());
      reservations.error = const ServerUnreachableException();

      final loaded = await send(bloc, const CalendarMoved(1));

      expect(loaded.date, DateTime(2026, 11, 20));
      expect(loaded.days, isEmpty);
      expect(loaded.refreshing, isFalse);
      expect(loaded.message, describeError(const ServerUnreachableException()));
    });

    test('osvežavanje posle greške briše poruku i učitava podatke', () async {
      await send(bloc, const CalendarStarted());
      reservations.error = const ServerUnreachableException();
      await send(bloc, const CalendarMoved(1));

      reservations.error = null;
      final loaded = await send(bloc, const CalendarRefreshed());

      expect(loaded.message, isNull);
      expect(loaded.days, hasLength(2));
    });

    test(
      'neuspelo osvežavanje zadržava stare podatke i javlja razlog',
      () async {
        final first = await send(bloc, const CalendarStarted());
        reservations.error = const ServerUnreachableException();

        final loaded = await send(bloc, const CalendarRefreshed());

        expect(loaded.days, first.days);
        expect(loaded.message, isNotNull);
      },
    );

    test('stariji odgovor ne prepisuje noviji opseg', () async {
      await send(bloc, const CalendarStarted());
      final gate = Completer<void>();
      reservations.gate = gate;

      // Prvo pomeranje čeka, drugo se završi pre njega.
      bloc.add(const CalendarMoved(1));
      await Future<void>.delayed(Duration.zero);
      final second = settled(bloc);
      bloc.add(const CalendarMoved(1));
      final loaded = await second as CalendarLoaded;
      expect(loaded.date, DateTime(2026, 11, 21));

      final states = <CalendarState>[];
      bloc.stream.listen(states.add);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states, isEmpty);
      expect((bloc.state as CalendarLoaded).date, DateTime(2026, 11, 21));
    });

    test('ponovni početak čuva prikaz i dan', () async {
      await send(bloc, const CalendarStarted());
      await send(bloc, const CalendarViewChanged(CalendarView.week));
      await send(bloc, const CalendarFieldSelected(field4));

      final loaded = await send(bloc, const CalendarStarted());

      expect(loaded.view, CalendarView.week);
      expect(loaded.field.id, field4);
    });
  });

  group('jednakost stanja', () {
    test('isto učitavanje daje jednako stanje', () async {
      final first = await send(bloc, const CalendarStarted());
      final second = await send(bloc, const CalendarRefreshed());

      expect(second, first);
    });
  });
}
