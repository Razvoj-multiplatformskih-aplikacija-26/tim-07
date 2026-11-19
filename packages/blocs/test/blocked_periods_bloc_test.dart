import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

const ownerId = UserId(100);
const field3 = FieldId(3);
const field4 = FieldId(4);
const foreignField = FieldId(9);

// Sada je četvrtak 19. 11. 2026. u podne; blokira se za petak 20. 11.
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

BlockedPeriod block(FieldId onField, int from, int to, [String? reason]) =>
    BlockedPeriod(
      fieldId: onField,
      startTime: friday(from),
      endTime: friday(to),
      reason: reason,
    );

/// Propušta pozive pravom repozitorijumu, broji ih i može da ih odbije.
final class _Spy implements FieldScheduleRepository {
  final FieldScheduleRepository inner;
  Object? error;
  int adds = 0;
  int removes = 0;
  int reads = 0;

  _Spy(this.inner);

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) async {
    adds++;
    final failure = error;
    if (failure != null) throw failure;
    return inner.addBlockedPeriod(period);
  }

  @override
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id) async {
    removes++;
    final failure = error;
    if (failure != null) throw failure;
    return inner.removeBlockedPeriod(fieldId, id);
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) {
    reads++;
    return inner.getBlockedPeriods(fieldId, from: from, to: to);
  }

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) =>
      inner.getSchedules(fieldId);

  @override
  Future<void> replaceSchedules(
    FieldId fieldId,
    List<FieldSchedule> schedules,
  ) => inner.replaceSchedules(fieldId, schedules);
}

/// Spisak terena koji može da padne, kao server koji ne radi.
final class _FlakyFields implements SportsFieldRepository {
  final SportsFieldRepository inner;
  Object? error;

  _FlakyFields(this.inner);

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

void main() {
  late FakeReservationRepository reservationStore;
  late FakeSportsFieldRepository fieldStore;
  late _FlakyFields fieldSource;
  late _Spy schedules;

  setUp(() {
    reservationStore = FakeReservationRepository(
      clock: () => now,
      reservations: [reservation(1, field3, 11)],
    );
    fieldStore = FakeSportsFieldRepository(
      fields: [
        field(3),
        field(4),
        field(9, by: const UserId(200)),
      ],
    );
    fieldSource = _FlakyFields(fieldStore);
    schedules = _Spy(
      FakeFieldScheduleRepository(
        reservations: reservationStore,
        clock: () => now,
        blockedPeriods: [
          block(field3, 14, 16, 'Održavanje'),
          block(field4, 8, 9),
          block(foreignField, 8, 9),
          // Prošla blokada se ne prikazuje.
          BlockedPeriod(
            fieldId: field3,
            startTime: DateTime(2026, 11, 18, 8),
            endTime: DateTime(2026, 11, 18, 10),
          ),
        ],
      ),
    );
  });

  BlockedPeriodsBloc bloc({
    AppUser? user,
    ReservationRepository? seenReservations,
  }) => BlockedPeriodsBloc(
    fields: fieldSource,
    schedules: schedules,
    reservations: seenReservations ?? reservationStore,
    owner: user ?? owner,
    clock: () => now,
  );

  Future<BlockedPeriodsBloc> loaded({
    AppUser? user,
    ReservationRepository? seenReservations,
  }) async {
    final b = bloc(user: user, seenReservations: seenReservations)
      ..add(const BlockedPeriodsStarted());
    await b.stream.firstWhere((s) => s is BlockedPeriodsLoaded);
    return b;
  }

  BlockedPeriodsLoaded ready(BlockedPeriodsBloc b) =>
      b.state as BlockedPeriodsLoaded;

  Future<void> settle(BlockedPeriodsBloc b) async {
    await pumpEventQueue();
    while (ready(b).busy) {
      await b.stream.first;
    }
  }

  group('učitavanje', () {
    test('početno stanje je učitavanje', () async {
      final b = bloc();

      expect(b.state, const BlockedPeriodsLoading());
      await b.close();
    });

    test(
      'Loading, pa Loaded sa terenima vlasnika i blokadama prvog terena',
      () async {
        final b = bloc()..add(const BlockedPeriodsStarted());

        final states = await b.stream.take(2).toList();

        expect(states[0], isA<BlockedPeriodsLoading>());
        final result = states[1] as BlockedPeriodsLoaded;
        expect(result.fields.map((f) => f.id), [field3, field4]);
        expect(result.field.id, field3);
        // Prošla blokada i blokade drugih terena se ne prikazuju.
        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.reason, 'Održavanje');
        expect(result.blocks.single.id, isNotNull);
        await b.close();
      },
    );

    test('tuđi tereni se ne vide', () async {
      final b = await loaded();

      expect(ready(b).fields.map((f) => f.id), isNot(contains(foreignField)));
      await b.close();
    });

    test('vlasnik bez terena dobija prazan prikaz', () async {
      final b = bloc(user: person(300, UserRole.owner))
        ..add(const BlockedPeriodsStarted());

      await b.stream.firstWhere((s) => s is BlockedPeriodsNoFields);
      await b.close();
    });

    test('nema mreže: poruka za korisnika, pa „pokušaj ponovo“ radi', () async {
      fieldSource.error = const ServerUnreachableException();
      final b = bloc()..add(const BlockedPeriodsStarted());

      final error = await b.stream.firstWhere((s) => s is BlockedPeriodsError);
      expect((error as BlockedPeriodsError).message, serverUnreachableMessage);

      fieldSource.error = null;
      b.add(const BlockedPeriodsStarted());
      await b.stream.firstWhere((s) => s is BlockedPeriodsLoaded);
      await b.close();
    });

    test('izbor drugog terena učitava njegove blokade', () async {
      final b = await loaded();

      b.add(const BlockedPeriodsFieldSelected(field4));
      await b.stream.firstWhere(
        (s) => s is BlockedPeriodsLoaded && s.field.id == field4,
      );

      expect(ready(b).blocks.single.startTime, friday(8));
      await b.close();
    });

    test('tuđi teren se ne može izabrati', () async {
      final b = await loaded();

      b.add(const BlockedPeriodsFieldSelected(foreignField));
      await pumpEventQueue();

      expect(ready(b).field.id, field3);
      await b.close();
    });

    test('osvežavanje čuva izabrani teren', () async {
      final b = await loaded();
      b.add(const BlockedPeriodsFieldSelected(field4));
      await pumpEventQueue();

      b.add(const BlockedPeriodsStarted());
      await b.stream.firstWhere((s) => s is BlockedPeriodsLoaded);

      expect(ready(b).field.id, field4);
      await b.close();
    });
  });

  group('dodavanje blokade', () {
    test('uspeh: blokada se vidi u spisku, po početku', () async {
      final b = await loaded();

      b.add(
        BlockedPeriodAddRequested(
          startTime: friday(8),
          endTime: friday(10),
          reason: '  Turnir  ',
        ),
      );
      await settle(b);

      final blocks = ready(b).blocks;
      expect(blocks.map((x) => x.startTime.hour), [8, 14]);
      expect(blocks.first.reason, 'Turnir');
      expect(blocks.first.id, isNotNull);
      expect(ready(b).message, isNull);
      expect(schedules.adds, 1);
      await b.close();
    });

    test('prazan razlog se ne čuva', () async {
      final b = await loaded();

      b.add(
        BlockedPeriodAddRequested(
          startTime: friday(8),
          endTime: friday(10),
          reason: '   ',
        ),
      );
      await settle(b);

      expect(ready(b).blocks.first.reason, isNull);
      await b.close();
    });

    test(
      'preko potvrđene rezervacije: razlog se prikazuje, ništa se ne šalje',
      () async {
        final b = await loaded();

        // Rezervacija 1 je potvrđena u petak od 11 do 12.
        b.add(
          BlockedPeriodAddRequested(startTime: friday(10), endTime: friday(13)),
        );
        await settle(b);

        expect(
          ready(b).message,
          const BlockOverlapsConfirmedReservation().message,
        );
        expect(schedules.adds, 0);
        expect(ready(b).blocks, hasLength(1));
        await b.close();
      },
    );

    test('kraj pre početka i prošli period se ne šalju', () async {
      final b = await loaded();

      b.add(
        BlockedPeriodAddRequested(startTime: friday(12), endTime: friday(10)),
      );
      await settle(b);
      expect(ready(b).message, const InvalidBlockRange().message);

      b.add(
        BlockedPeriodAddRequested(
          startTime: DateTime(2026, 11, 18, 8),
          endTime: DateTime(2026, 11, 18, 10),
        ),
      );
      await settle(b);
      expect(ready(b).message, const BlockInPast().message);
      expect(schedules.adds, 0);
      await b.close();
    });

    test('poruka nestaje kada sledeća blokada uspe', () async {
      final b = await loaded();
      b.add(
        BlockedPeriodAddRequested(startTime: friday(12), endTime: friday(10)),
      );
      await settle(b);
      expect(ready(b).message, isNotNull);

      b.add(
        BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
      );
      await settle(b);

      expect(ready(b).message, isNull);
      await b.close();
    });

    test('server odbija blokadu koju klijent nije mogao da vidi: ista poruka, spisak se osvežava', () async {
      // Klijent ne zna za rezervacije (stariji podaci), a server ih zna.
      final stale = FakeReservationRepository(clock: () => now);
      final b = await loaded(seenReservations: stale);
      final reads = schedules.reads;

      b.add(
        BlockedPeriodAddRequested(startTime: friday(10), endTime: friday(13)),
      );
      await settle(b);

      expect(
        ready(b).message,
        const BlockOverlapsConfirmedReservation().message,
      );
      expect(schedules.adds, 1);
      expect(schedules.reads, greaterThan(reads));
      expect(ready(b).blocks, hasLength(1));
      await b.close();
    });

    test('nema mreže: poruka, spisak ostaje', () async {
      schedules.error = const ServerUnreachableException();
      final b = await loaded();

      b.add(
        BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
      );
      // Čitanje spiska ne pada, pa se prikaz vraća na spisak sa porukom.
      await settle(b);

      expect(ready(b).message, serverUnreachableMessage);
      expect(ready(b).blocks, hasLength(1));
      await b.close();
    });

    test('nepoznat kod greške daje opštu poruku', () async {
      schedules.error = const FormatException('Unexpected character');
      final b = await loaded();

      b.add(
        BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
      );
      await settle(b);

      expect(ready(b).message, genericErrorMessage);
      await b.close();
    });

    test('dvostruki klik šalje jedan zahtev', () async {
      final b = await loaded();

      b
        ..add(
          BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
        )
        ..add(
          BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
        );
      await settle(b);

      expect(schedules.adds, 1);
      await b.close();
    });
  });

  group('vlasništvo', () {
    test('korisnik koji nije vlasnik tog terena ne šalje ništa', () async {
      // Administrator može da pročita terene vlasnika, ali ih ne menja.
      final admin = person(100, UserRole.admin);
      final b = await loaded(user: admin);

      b.add(
        BlockedPeriodAddRequested(startTime: friday(18), endTime: friday(20)),
      );
      await settle(b);

      expect(ready(b).message, 'Nemate pravo na ovu radnju.');
      expect(schedules.adds, 0);

      b.add(BlockedPeriodRemoveRequested(ready(b).blocks.first));
      await settle(b);
      expect(schedules.removes, 0);
      await b.close();
    });
  });

  group('brisanje blokade', () {
    test('uspeh: blokada nestaje iz spiska', () async {
      final b = await loaded();

      b.add(BlockedPeriodRemoveRequested(ready(b).blocks.single));
      await settle(b);

      expect(ready(b).blocks, isEmpty);
      expect(schedules.removes, 1);
      await b.close();
    });

    test('greška pri brisanju: poruka i osvežen spisak', () async {
      final b = await loaded();
      schedules.error = const ServerUnreachableException();

      b.add(BlockedPeriodRemoveRequested(ready(b).blocks.single));
      await settle(b);

      expect(ready(b).message, serverUnreachableMessage);
      expect(ready(b).blocks, hasLength(1));
      await b.close();
    });

    test('blokada bez identifikatora se ne šalje', () async {
      final b = await loaded();

      b.add(BlockedPeriodRemoveRequested(block(field3, 18, 20)));
      await settle(b);

      expect(schedules.removes, 0);
      await b.close();
    });

    test('blokada drugog terena se ne briše kroz izabrani teren', () async {
      final b = await loaded();
      final other = (await schedules.getBlockedPeriods(field4)).single;

      b.add(BlockedPeriodRemoveRequested(other));
      await settle(b);

      expect(schedules.removes, 0);
      await b.close();
    });

    test('posle brisanja isti termin može ponovo da se blokira', () async {
      final b = await loaded();
      b.add(BlockedPeriodRemoveRequested(ready(b).blocks.single));
      await settle(b);

      b.add(
        BlockedPeriodAddRequested(startTime: friday(14), endTime: friday(16)),
      );
      await settle(b);

      expect(ready(b).blocks, hasLength(1));
      expect(ready(b).message, isNull);
      await b.close();
    });
  });

  group('stanja', () {
    test('ista stanja su jednaka, različita poruka nije', () async {
      final a = BlockedPeriodsLoaded(
        fields: [field(3)],
        field: field(3),
        blocks: const [],
      );

      expect(a.copyWith(message: 'x'), isNot(a));
      expect(a.copyWith(busy: true), isNot(a));
      expect(a, equals(a.copyWith()));
    });
  });
}
