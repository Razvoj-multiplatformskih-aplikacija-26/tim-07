import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);

// Četvrtak 19. 11. 2026. u podne je "sada"; sutra je petak 20. 11.
final now = DateTime(2026, 11, 19, 12);
final today = DateTime(2026, 11, 19);
final friday = DateTime(2026, 11, 20);
final saturday = DateTime(2026, 11, 21);

FieldSchedule schedule(
  WeekDay day, {
  int opens = 8,
  int closes = 23,
  bool isOpen = true,
}) => FieldSchedule(
  fieldId: fieldId,
  dayOfWeek: day,
  opensAt: TimeOfDay(hour: opens, minute: 0),
  closesAt: TimeOfDay(hour: closes, minute: 0),
  isOpen: isOpen,
);

final schedules = [
  schedule(WeekDay.thursday),
  schedule(WeekDay.friday, opens: 10, closes: 14),
  schedule(WeekDay.saturday, isOpen: false),
];

/// Izvor koji odbija poziv zadatom greškom, ili odgovara tek kada test dozvoli.
final class _ControlledRepository implements AvailabilityRepository {
  final AvailabilityRepository inner;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  _ControlledRepository(this.inner);

  // Ishod se određuje u trenutku poziva, a stiže tek kada se otvori kapija.
  @override
  Future<List<AvailabilitySlot>> getAvailability({
    required FieldId fieldId,
    required DateTime date,
  }) async {
    calls++;
    final failure = error;
    final wait = gate;
    final result = failure == null
        ? await inner.getAvailability(fieldId: fieldId, date: date)
        : null;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
    return result!;
  }
}

void main() {
  late FakeReservationRepository store;
  late FakeAvailabilityRepository fake;
  late _ControlledRepository source;
  var blocked = <BlockedPeriod>[];

  setUp(() {
    blocked = [];
    store = FakeReservationRepository(
      clock: () => now,
      fields: [
        SportsField(
          id: fieldId,
          ownerId: const UserId(100),
          name: 'Padel Arena',
          description: 'Opis',
          sport: SportType.padel,
          address: 'A 1',
          city: 'Beograd',
          pricePerHour: 3000,
          contactPhone: '060',
          confirmationMode: ConfirmationMode.manual,
        ),
      ],
      schedules: schedules,
      reservations: [
        Reservation(
          id: const ReservationId(1),
          fieldId: fieldId,
          userId: const UserId(7),
          startTime: DateTime(2026, 11, 20, 11),
          endTime: DateTime(2026, 11, 20, 12),
          totalPrice: 3000,
          status: ReservationStatus.confirmed,
          createdAt: DateTime(2026, 11, 1),
        ),
      ],
    );
    fake = FakeAvailabilityRepository(
      reservations: store,
      schedules: schedules,
      blockedPeriods: blocked,
      clock: () => now,
    );
    source = _ControlledRepository(fake);
  });

  AvailabilityBloc bloc() =>
      AvailabilityBloc(repository: source, fieldId: fieldId, clock: () => now);

  Future<AvailabilityBloc> loaded({DateTime? day}) async {
    final b = bloc();
    if (day != null) b.add(AvailabilityDaySelected(day));
    if (day == null) b.add(const AvailabilityRequested());
    await b.stream.firstWhere((s) => s is AvailabilityLoaded);
    return b;
  }

  group('učitavanje termina', () {
    test('početno stanje je učitavanje današnjeg dana', () async {
      final b = bloc();

      expect(b.state, AvailabilityLoading(day: today));
      await b.close();
    });

    test('Loading, pa Loaded sa terminima iz radnog vremena', () async {
      final b = bloc()..add(const AvailabilityRequested());

      final states = await b.stream.take(2).toList();

      expect(states[0], isA<AvailabilityLoading>());
      final result = states[1] as AvailabilityLoaded;
      expect(result.day, today);
      // Četvrtak je otvoren 08-23: 15 termina. Sada je 12:00, pa je i termin koji
      // počinje u 12:00 već počeo (isto kao u pravilu rezervisanja).
      expect(result.slots, hasLength(15));
      expect(result.slots.first.startTime, DateTime(2026, 11, 19, 8));
      expect(result.slots.last.endTime, DateTime(2026, 11, 19, 23));
      expect(result.slots[4].state, SlotState.past);
      expect(result.slots[5].state, SlotState.free);
      expect(result.freeCount, 10);
      await b.close();
    });

    test(
      'termini prate radno vreme izabranog dana, a ne fiksnu listu',
      () async {
        final b = await loaded(day: friday);

        // Petak je otvoren samo 10-14.
        expect((b.state as AvailabilityLoaded).slots, hasLength(4));
        await b.close();
      },
    );

    test('zauzet termin dolazi iz rezervacije drugog korisnika', () async {
      final b = await loaded(day: friday);

      final slots = (b.state as AvailabilityLoaded).slots;
      expect(slots.map((s) => s.state), [
        SlotState.free,
        SlotState.taken,
        SlotState.free,
        SlotState.free,
      ]);
      expect((b.state as AvailabilityLoaded).freeCount, 3);
      await b.close();
    });

    test(
      'dan na koji teren ne radi je Empty, ne Loaded sa praznom listom',
      () async {
        final b = bloc()..add(AvailabilityDaySelected(saturday));

        final state = await b.stream.firstWhere((s) => s is AvailabilityEmpty);

        expect(state.day, saturday);
        await b.close();
      },
    );

    test('dan bez sata: vreme izabranog dana se odseca', () async {
      final b = bloc()
        ..add(AvailabilityDaySelected(DateTime(2026, 11, 20, 17, 45)));

      final state = await b.stream.firstWhere((s) => s is AvailabilityLoaded);

      expect(state.day, friday);
      await b.close();
    });

    test('promena dana učitava novi dan i zadržava ga u stanjima', () async {
      final b = await loaded();
      final calls = source.calls;

      b.add(AvailabilityDaySelected(friday));
      final states = await b.stream.take(2).toList();

      expect(states[0], AvailabilityLoading(day: friday));
      expect(states[1].day, friday);
      expect(source.calls, calls + 1);
      await b.close();
    });
  });

  group('greške', () {
    test('nema mreže: poruka za korisnika, pa „pokušaj ponovo“ radi', () async {
      source.error = const ServerUnreachableException();
      final b = bloc()..add(const AvailabilityRequested());

      final error = await b.stream.firstWhere((s) => s is AvailabilityError);

      expect((error as AvailabilityError).message, serverUnreachableMessage);
      expect(error.day, today);

      source.error = null;
      b.add(const AvailabilityRequested());
      await b.stream.firstWhere((s) => s is AvailabilityLoaded);
      await b.close();
    });

    test(
      'greška čuva izabrani dan, pa ponovni pokušaj ide na isti dan',
      () async {
        final b = bloc();
        source.error = const ServerUnreachableException();
        b.add(AvailabilityDaySelected(friday));
        await b.stream.firstWhere((s) => s is AvailabilityError);

        source.error = null;
        b.add(const AvailabilityRequested());
        final state = await b.stream.firstWhere((s) => s is AvailabilityLoaded);

        expect(state.day, friday);
        await b.close();
      },
    );

    test('nepoznata greška servera nije tehnički tekst', () async {
      source.error = const FormatException('Unexpected character at 0');
      final b = bloc()..add(const AvailabilityRequested());

      final error = await b.stream.firstWhere((s) => s is AvailabilityError);

      expect((error as AvailabilityError).message, genericErrorMessage);
      await b.close();
    });
  });

  group('osvežavanje i zastareli odgovori', () {
    test(
      'posle nove rezervacije osvežavanje prikazuje termin kao zauzet',
      () async {
        final b = await loaded(day: friday);
        expect(
          (b.state as AvailabilityLoaded).slots.first.state,
          SlotState.free,
        );

        await store.createReservation(
          fieldId: fieldId,
          userId: const UserId(1),
          startTime: DateTime(2026, 11, 20, 10),
          endTime: DateTime(2026, 11, 20, 11),
        );
        b.add(const AvailabilityRequested());
        await b.stream.firstWhere((s) => s is AvailabilityLoaded);

        expect(
          (b.state as AvailabilityLoaded).slots.first.state,
          SlotState.taken,
        );
        await b.close();
      },
    );

    test('odgovor starijeg zahteva ne prepisuje noviji', () async {
      final b = bloc();
      final gate = Completer<void>();

      // Prvi zahtev (petak) kasni, drugi (četvrtak) stiže prvi.
      source.gate = gate;
      b.add(AvailabilityDaySelected(friday));
      await pumpEventQueue();
      source.gate = null;
      b.add(AvailabilityDaySelected(today));
      await b.stream.firstWhere(
        (s) => s is AvailabilityLoaded && s.day == today,
      );

      gate.complete();
      await pumpEventQueue();

      expect(b.state.day, today);
      expect(b.state, isA<AvailabilityLoaded>());
      await b.close();
    });
  });

  group('FakeAvailabilityRepository', () {
    test('koristi rezervacije svih korisnika i vreme iz sata', () async {
      final slots = await fake.getAvailability(fieldId: fieldId, date: friday);

      expect(slots[1].state, SlotState.taken);
      expect(slots[0].state, SlotState.free);
    });

    test('blokirani periodi dolaze iz izvora', () async {
      final withBlock = FakeAvailabilityRepository(
        reservations: store,
        schedules: schedules,
        blockedPeriods: [
          BlockedPeriod(
            fieldId: fieldId,
            startTime: DateTime(2026, 11, 20, 12),
            endTime: DateTime(2026, 11, 20, 14),
            reason: 'Održavanje',
          ),
        ],
        clock: () => now,
      );

      final slots = await withBlock.getAvailability(
        fieldId: fieldId,
        date: friday,
      );

      expect(slots.map((s) => s.state), [
        SlotState.free,
        SlotState.taken,
        SlotState.blocked,
        SlotState.blocked,
      ]);
    });

    test('sat određuje koji su termini prošli', () async {
      final later = FakeAvailabilityRepository(
        reservations: store,
        schedules: schedules,
        clock: () => DateTime(2026, 11, 20, 12, 30),
      );

      final slots = await later.getAvailability(fieldId: fieldId, date: friday);

      expect(slots.map((s) => s.state), [
        SlotState.past,
        SlotState.past,
        SlotState.past,
        SlotState.free,
      ]);
    });
  });

  group('stanja', () {
    test('isti termini u istom danu su isto stanje', () {
      final slot = AvailabilitySlot(
        startTime: DateTime(2026, 11, 20, 10),
        endTime: DateTime(2026, 11, 20, 11),
        state: SlotState.free,
      );

      expect(
        AvailabilityLoaded(slots: [slot], day: friday),
        AvailabilityLoaded(slots: [slot], day: friday),
      );
      expect(
        AvailabilityLoaded(slots: [slot], day: friday),
        isNot(AvailabilityLoaded(slots: [slot], day: saturday)),
      );
      expect(
        AvailabilityLoading(day: friday),
        isNot(AvailabilityEmpty(day: friday)),
      );
    });
  });
}
