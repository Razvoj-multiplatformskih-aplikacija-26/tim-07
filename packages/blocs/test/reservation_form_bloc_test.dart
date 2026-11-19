import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

const fieldId = FieldId(3);
const otherField = FieldId(5);
const me = UserId(1);
const stranger = UserId(7);

// Sada je četvrtak 19. 11. 2026. u podne; rezerviše se za sutra, petak 20. 11.
final now = DateTime(2026, 11, 19, 12);
final friday = DateTime(2026, 11, 20);

final field = SportsField(
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
);

final schedules = [
  for (final day in WeekDay.values)
    FieldSchedule(
      fieldId: fieldId,
      dayOfWeek: day,
      opensAt: const TimeOfDay(hour: 8, minute: 0),
      closesAt: const TimeOfDay(hour: 23, minute: 0),
    ),
];

final blocked = [
  BlockedPeriod(
    fieldId: fieldId,
    startTime: DateTime(2026, 11, 20, 12),
    endTime: DateTime(2026, 11, 20, 13),
    reason: 'Održavanje',
  ),
];

Reservation reservation(int id, UserId user, FieldId onField, int hour) =>
    Reservation(
      id: ReservationId(id),
      fieldId: onField,
      userId: user,
      startTime: DateTime(2026, 11, 20, hour),
      endTime: DateTime(2026, 11, 20, hour + 1),
      totalPrice: 3000,
      status: ReservationStatus.confirmed,
      createdAt: DateTime(2026, 11, 1),
    );

/// Rezervacije koje poznaje server: moja na drugom terenu u 16 h i tuđa na ovom u 10 h.
List<Reservation> existing() => [
  reservation(1, me, otherField, 16),
  reservation(2, stranger, fieldId, 10),
];

/// Propušta pozive pravom repozitorijumu, ali može da ih odbije i da ih zadrži.
final class _Controlled implements ReservationRepository {
  final ReservationRepository inner;
  Object? createError;
  Completer<void>? gate;
  int creates = 0;
  int byUserCalls = 0;

  _Controlled(this.inner);

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    creates++;
    final wait = gate;
    if (wait != null) await wait.future;
    final failure = createError;
    if (failure != null) throw failure;
    return inner.createReservation(
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
    );
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) {
    byUserCalls++;
    return inner.getReservationsByUser(userId);
  }

  @override
  Future<List<Reservation>> getReservations() => inner.getReservations();

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) =>
      inner.getReservationsByField(fieldId);

  @override
  Future<Reservation?> getReservationById(ReservationId id) =>
      inner.getReservationById(id);

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

/// Radno vreme koje može da padne, kao server koji ne odgovara.
final class _FlakySchedules implements FieldScheduleRepository {
  final FieldScheduleRepository inner;
  Object? error;

  _FlakySchedules(this.inner);

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) async {
    final failure = error;
    if (failure != null) throw failure;
    return inner.getSchedules(fieldId);
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) => inner.getBlockedPeriods(fieldId, from: from, to: to);

  @override
  Future<void> replaceSchedules(
    FieldId fieldId,
    List<FieldSchedule> schedules,
  ) => inner.replaceSchedules(fieldId, schedules);

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) =>
      inner.addBlockedPeriod(period);
}

void main() {
  late FakeReservationRepository store;
  late _Controlled server;
  late _FlakySchedules scheduleSource;

  setUp(() {
    store = FakeReservationRepository(
      clock: () => now,
      fields: [field],
      schedules: schedules,
      blockedPeriods: blocked,
      reservations: existing(),
    );
    server = _Controlled(store);
    scheduleSource = _FlakySchedules(
      FakeFieldScheduleRepository(
        schedules: schedules,
        blockedPeriods: blocked,
      ),
    );
  });

  ReservationFormBloc bloc({
    String start = '14:00',
    String end = '15:00',
    DateTime? date,
    DateTime Function()? clock,
  }) => ReservationFormBloc(
    reservations: server,
    schedules: scheduleSource,
    field: field,
    userId: me,
    date: date ?? friday,
    initialStart: start,
    initialEnd: end,
    clock: clock ?? () => now,
  );

  Future<ReservationFormBloc> started({
    String start = '14:00',
    String end = '15:00',
  }) async {
    final b = bloc(start: start, end: end)..add(const ReservationFormStarted());
    await b.stream.firstWhere((s) => s is ReservationFormEditing);
    return b;
  }

  ReservationFormEditing editing(ReservationFormBloc b) =>
      b.state as ReservationFormEditing;

  group('priprema i provera termina', () {
    test('počinje učitavanjem sa unosom koji je došao sa adrese', () async {
      final b = bloc(start: '12:00', end: '13:00');

      expect(
        b.state,
        const ReservationFormLoading(startText: '12:00', endText: '13:00'),
      );
      await b.close();
    });

    test('Loading, pa Editing sa cenom kada je termin ispravan', () async {
      final b = bloc()..add(const ReservationFormStarted());

      final states = await b.stream.take(2).toList();

      expect(states[0], isA<ReservationFormLoading>());
      final form = states[1] as ReservationFormEditing;
      expect(form.canSubmit, isTrue);
      expect(form.price, 3000);
      expect(form.slotError, isNull);
      await b.close();
    });

    test('cena je srazmerna trajanju', () async {
      final b = await started(start: '14:00', end: '15:30');

      expect(editing(b).price, 4500);
      await b.close();
    });

    test('vreme koje nije HH:mm se prijavljuje, ne šalje', () async {
      final b = await started();

      b.add(const ReservationFormStartChanged('abc'));
      await pumpEventQueue();

      expect(editing(b).startInvalid, isTrue);
      expect(editing(b).endInvalid, isFalse);
      expect(editing(b).canSubmit, isFalse);
      expect(editing(b).price, isNull);
      await b.close();
    });

    test('nemoguća vremena (25:00, 12:75) nisu vreme', () async {
      final b = await started();

      b.add(const ReservationFormEndChanged('25:00'));
      await pumpEventQueue();
      expect(editing(b).endInvalid, isTrue);

      b.add(const ReservationFormEndChanged('12:75'));
      await pumpEventQueue();
      expect(editing(b).endInvalid, isTrue);
      await b.close();
    });

    test('kraj pre početka je InvalidTimeRange, bez cene', () async {
      final b = await started(start: '15:00', end: '14:00');

      expect(editing(b).slotError, isA<InvalidTimeRange>());
      expect(editing(b).price, isNull);
      expect(editing(b).canSubmit, isFalse);
      await b.close();
    });

    test('van radnog vremena', () async {
      final b = await started(start: '22:00', end: '23:30');

      expect(editing(b).slotError, isA<OutsideWorkingHours>());
      await b.close();
    });

    test('blokiran termin', () async {
      final b = await started(start: '12:00', end: '13:00');

      expect(editing(b).slotError, isA<FieldBlocked>());
      await b.close();
    });

    test(
      'termin u kome korisnik već ima rezervaciju na drugom terenu',
      () async {
        final b = await started(start: '16:00', end: '17:00');

        expect(editing(b).slotError, isA<SlotAlreadyTaken>());
        await b.close();
      },
    );

    test('prošao termin', () async {
      final b = bloc(start: '09:00', end: '10:00', date: DateTime(2026, 11, 19))
        ..add(const ReservationFormStarted());
      await b.stream.firstWhere((s) => s is ReservationFormEditing);

      expect(editing(b).slotError, isA<ReservationInPast>());
      await b.close();
    });

    test('promena unosa proverava uživo, istim pravilima kao server', () async {
      final b = await started();

      b.add(const ReservationFormStartChanged('12:00'));
      b.add(const ReservationFormEndChanged('13:00'));
      await pumpEventQueue();

      expect(editing(b).slotError, isA<FieldBlocked>());

      b.add(const ReservationFormStartChanged('13:00'));
      b.add(const ReservationFormEndChanged('14:00'));
      await pumpEventQueue();

      expect(editing(b).slotError, isNull);
      expect(editing(b).canSubmit, isTrue);
      await b.close();
    });

    test('dok se podaci učitavaju, izmena unosa se ne primenjuje', () async {
      final b = bloc();

      b.add(const ReservationFormStartChanged('10:00'));
      await pumpEventQueue();

      expect(b.state, isA<ReservationFormLoading>());
      expect(b.state.startText, '14:00');
      await b.close();
    });

    test('ne može da se učita: poruka, pa „pokušaj ponovo“ radi', () async {
      scheduleSource.error = const ServerUnreachableException();
      final b = bloc()..add(const ReservationFormStarted());

      final failed = await b.stream.firstWhere(
        (s) => s is ReservationFormLoadFailed,
      );
      expect(
        (failed as ReservationFormLoadFailed).message,
        serverUnreachableMessage,
      );
      expect(failed.startText, '14:00');

      scheduleSource.error = null;
      b.add(const ReservationFormStarted());
      await b.stream.firstWhere((s) => s is ReservationFormEditing);
      await b.close();
    });
  });

  group('slanje', () {
    test('uspeh: Submitting, pa Succeeded sa rezervacijom korisnika', () async {
      final b = await started(start: '14:00', end: '15:30');
      final states = <ReservationFormState>[];
      final subscription = b.stream.listen(states.add);

      b.add(const ReservationFormSubmitted());
      await pumpEventQueue();

      expect(states[0], isA<ReservationFormSubmitting>());
      final done = states[1] as ReservationFormSucceeded;
      expect(done.reservation.userId, me);
      expect(done.reservation.fieldId, fieldId);
      expect(done.reservation.totalPrice, 4500);
      expect(done.reservation.startTime, DateTime(2026, 11, 20, 14));
      expect(await store.getReservationsByUser(me), hasLength(2));

      await subscription.cancel();
      await b.close();
    });

    test(
      'neispravan unos se ne šalje, već se prikazuje šta ne valja',
      () async {
        final b = await started(start: '12:00', end: '13:00');

        b.add(const ReservationFormSubmitted());
        await pumpEventQueue();

        expect(server.creates, 0);
        expect(b.state, isA<ReservationFormEditing>());
        expect(editing(b).slotError, isA<FieldBlocked>());
        await b.close();
      },
    );

    test('dvostruki klik šalje jedan zahtev', () async {
      final gate = Completer<void>();
      server.gate = gate;
      final b = await started();

      b
        ..add(const ReservationFormSubmitted())
        ..add(const ReservationFormSubmitted());
      await pumpEventQueue();
      gate.complete();
      await b.stream.firstWhere((s) => s is ReservationFormSucceeded);

      expect(server.creates, 1);
      await b.close();
    });

    test('posle uspeha izmena unosa se ignoriše', () async {
      final b = await started();
      b.add(const ReservationFormSubmitted());
      await b.stream.firstWhere((s) => s is ReservationFormSucceeded);

      b.add(const ReservationFormStartChanged('09:00'));
      await pumpEventQueue();

      expect(b.state, isA<ReservationFormSucceeded>());
      expect(b.state.startText, '14:00');
      await b.close();
    });
  });

  group('odbijanje sa servera', () {
    test(
      'termin koji je u međuvremenu zauzet: ista poruka kao lokalna provera',
      () async {
        // Tuđa rezervacija 10-11 na ovom terenu klijent ne vidi, pa lokalna provera prolazi.
        final b = await started(start: '10:00', end: '11:00');
        expect(editing(b).canSubmit, isTrue);

        b.add(const ReservationFormSubmitted());
        final rejected = await b.stream.firstWhere(
          (s) => s is ReservationFormRejected,
        ) as ReservationFormRejected;

        expect(rejected.message, validationMessage(const SlotAlreadyTaken()));
        expect(
          rejected.message,
          'Termin se preklapa sa postojećom rezervacijom.',
        );
        // Unos ostaje, pa korisnik može da izabere drugi termin.
        expect(rejected.startText, '10:00');
        expect(rejected.endText, '11:00');
        await b.close();
      },
    );

    test(
      'kod i podaci sa servera daju istu poruku kao pravilo u klijentu',
      () async {
        server.createError = ServerRejectedException(
          const CancellationDeadlineExpired().toErrorDto(),
        );
        final b = await started();

        b.add(const ReservationFormSubmitted());
        final rejected = await b.stream.firstWhere(
          (s) => s is ReservationFormRejected,
        ) as ReservationFormRejected;

        expect(
          rejected.message,
          validationMessage(const CancellationDeadlineExpired()),
        );
        await b.close();
      },
    );

    test('posle odbijanja se podaci za proveru ponovo učitavaju', () async {
      final b = await started(start: '10:00', end: '11:00');
      final loadsBefore = server.byUserCalls;

      b.add(const ReservationFormSubmitted());
      await b.stream.firstWhere((s) => s is ReservationFormRejected);
      await pumpEventQueue();

      expect(server.byUserCalls, loadsBefore + 1);
      await b.close();
    });

    test('posle odbijanja korisnik bira drugi termin i uspeva', () async {
      final b = await started(start: '10:00', end: '11:00');
      b.add(const ReservationFormSubmitted());
      await b.stream.firstWhere((s) => s is ReservationFormRejected);

      b.add(const ReservationFormStartChanged('18:00'));
      b.add(const ReservationFormEndChanged('19:00'));
      await pumpEventQueue();
      expect(b.state, isA<ReservationFormEditing>());

      b.add(const ReservationFormSubmitted());
      await b.stream.firstWhere((s) => s is ReservationFormSucceeded);
      await b.close();
    });

    test('nepoznat kod greške (stara aplikacija) daje opštu poruku', () async {
      server.createError = const ServerRejectedException(
        ErrorDto(code: 'court_closed_for_holiday'),
      );
      final b = await started();

      b.add(const ReservationFormSubmitted());
      final rejected = await b.stream.firstWhere(
        (s) => s is ReservationFormRejected,
      ) as ReservationFormRejected;

      expect(rejected.message, genericErrorMessage);
      await b.close();
    });

    test(
      'nema mreže: poruka, unos ostaje i može da se pošalje ponovo',
      () async {
        server.createError = const ServerUnreachableException();
        final b = await started();
        final loadsBefore = server.byUserCalls;

        b.add(const ReservationFormSubmitted());
        final failed = await b.stream.firstWhere(
          (s) => s is ReservationFormFailed,
        ) as ReservationFormFailed;

        expect(failed.message, serverUnreachableMessage);
        expect(failed.startText, '14:00');
        // Mreža nije pravilo, pa se podaci ne učitavaju ponovo.
        expect(server.byUserCalls, loadsBefore);

        server.createError = null;
        b.add(const ReservationFormSubmitted());
        await b.stream.firstWhere((s) => s is ReservationFormSucceeded);
        await b.close();
      },
    );
  });

  group('stanja', () {
    test('ista stanja su jednaka, različit unos nije', () {
      expect(
        const ReservationFormEditing(startText: '10:00', endText: '11:00'),
        const ReservationFormEditing(startText: '10:00', endText: '11:00'),
      );
      expect(
        const ReservationFormEditing(startText: '10:00', endText: '11:00'),
        isNot(
          const ReservationFormEditing(startText: '10:00', endText: '12:00'),
        ),
      );
      expect(
        const ReservationFormRejected('a', startText: '1', endText: '2'),
        isNot(const ReservationFormRejected('b', startText: '1', endText: '2')),
      );
    });

    test('parseTimeOnDate', () {
      expect(parseTimeOnDate(friday, '9:05'), DateTime(2026, 11, 20, 9, 5));
      expect(parseTimeOnDate(friday, ' 18:00 '), DateTime(2026, 11, 20, 18));
      expect(parseTimeOnDate(friday, '24:00'), isNull);
      expect(parseTimeOnDate(friday, '18'), isNull);
      expect(parseTimeOnDate(friday, ''), isNull);
    });
  });
}
