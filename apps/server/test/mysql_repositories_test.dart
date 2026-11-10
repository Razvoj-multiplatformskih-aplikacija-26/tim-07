@Tags(['db'])
library;

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

void main() {
  TestDatabase? testDb;

  // "Sada" je ponedeljak 3. 6. 2030. u 10:00 po lokalnom vremenu.
  var now = DateTime(2030, 6, 3, 10);
  DateTime at(int day, int hour, [int minute = 0]) => DateTime(2030, 6, day, hour, minute);

  late MySqlReservationRepository reservations;
  late MySqlSportsFieldRepository fields;
  late MySqlFieldScheduleRepository schedules;
  late MySqlUserRepository users;

  setUp(() async {
    now = DateTime(2030, 6, 3, 10);
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    await testDb!.migrate();
    final db = testDb!.database;
    await insertFixtures(db);
    reservations = MySqlReservationRepository(db, clock: () => now);
    fields = MySqlSportsFieldRepository(db);
    schedules = MySqlFieldScheduleRepository(db);
    users = MySqlUserRepository(db);
  });

  tearDown(() async => testDb?.dispose());

  Matcher violates<T extends ReservationValidationError>() => throwsA(
        isA<ReservationRuleViolation>().having((e) => e.error, 'error', isA<T>()),
      );

  group('MySqlReservationRepository', () {
    test('kreira rezervaciju: cena iz domena, stanje po načinu potvrde, vreme u UTC', () async {
      if (testDb == null) return;

      final manual = await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19, 30),
      );
      final automatic = await reservations.createReservation(
        fieldId: FieldId(2), userId: UserId(2), startTime: at(4, 18), endTime: at(4, 19),
      );

      expect(manual.totalPrice, 4500);
      expect(manual.status, ReservationStatus.pending);
      expect(automatic.status, ReservationStatus.confirmed);
      expect(manual.startTime.isUtc, isTrue);
      expect(manual.startTime, at(4, 18).toUtc());

      final stored = await reservations.getReservationById(manual.id);
      expect(stored!.endTime, at(4, 19, 30).toUtc());
      expect(await reservations.getReservationsByUser(UserId(1)), hasLength(1));
      expect(await reservations.getReservationsByField(FieldId(2)), hasLength(1));
      expect(await reservations.getReservationsByOwner(UserId(3)), hasLength(2));
    });

    test('preklapanje na istom terenu odbija se istim pravilom iz domena', () async {
      if (testDb == null) return;
      await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 20),
      );

      expect(
        reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(2), startTime: at(4, 19), endTime: at(4, 21),
        ),
        violates<SlotAlreadyTaken>(),
      );
      // Termin koji počinje tačno kad prethodni završi nije preklapanje.
      await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(2), startTime: at(4, 20), endTime: at(4, 21),
      );
    });

    test('isti korisnik ne može u isto vreme na dva terena', () async {
      if (testDb == null) return;
      await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 20),
      );

      expect(
        reservations.createReservation(
          fieldId: FieldId(2), userId: UserId(1), startTime: at(4, 19), endTime: at(4, 20),
        ),
        violates<SlotAlreadyTaken>(),
      );
    });

    test('otkazana rezervacija oslobađa termin', () async {
      if (testDb == null) return;
      final first = await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 20),
      );
      await reservations.cancelReservation(first.id);

      final second = await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(2), startTime: at(4, 18), endTime: at(4, 20),
      );
      expect(second.status, ReservationStatus.pending);
    });

    test('van radnog vremena, u prošlosti i obrnut interval', () async {
      if (testDb == null) return;

      expect(
        reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 22), endTime: at(4, 23, 30),
        ),
        violates<OutsideWorkingHours>(),
      );
      expect(
        reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(1), startTime: at(3, 8), endTime: at(3, 9),
        ),
        violates<ReservationInPast>(),
      );
      expect(
        reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 19), endTime: at(4, 18),
        ),
        violates<InvalidTimeRange>(),
      );
    });

    test('blokiran period odbija rezervaciju', () async {
      if (testDb == null) return;
      await schedules.addBlockedPeriod(BlockedPeriod(
        fieldId: FieldId(1), startTime: at(5, 12), endTime: at(5, 14), reason: 'Održavanje',
      ));

      expect(
        reservations.createReservation(
          fieldId: FieldId(1), userId: UserId(1), startTime: at(5, 13), endTime: at(5, 15),
        ),
        violates<FieldBlocked>(),
      );
    });

    test('neodobren teren i nepostojeći teren', () async {
      if (testDb == null) return;

      expect(
        reservations.createReservation(
          fieldId: FieldId(3), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19),
        ),
        violates<FieldUnavailable>(),
      );
      expect(
        reservations.createReservation(
          fieldId: FieldId(99), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19),
        ),
        throwsA(isA<EntityNotFound>()),
      );
    });

    test('potvrda, pa nedozvoljen prelaz i ručni završetak', () async {
      if (testDb == null) return;
      final created = await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(5, 18), endTime: at(5, 19),
      );

      final confirmed = await reservations.updateReservationStatus(
        reservationId: created.id, status: ReservationStatus.confirmed,
      );
      expect(confirmed.status, ReservationStatus.confirmed);
      expect(
        reservations.updateReservationStatus(reservationId: created.id, status: ReservationStatus.pending),
        violates<InvalidReservationStatus>(),
      );
      expect(
        reservations.updateReservationStatus(reservationId: created.id, status: ReservationStatus.completed),
        violates<InvalidReservationStatus>(),
      );
    });

    test('otkazivanje manje od 5 sati pre početka se odbija', () async {
      if (testDb == null) return;
      final created = await reservations.createReservation(
        fieldId: FieldId(2), userId: UserId(1), startTime: at(3, 18), endTime: at(3, 19),
      );

      // Sa check-in-om potvrđena rezervacija ostaje potvrđena i posle roka
      // (bez njega bi je domen već otkazao, pa bi greška bila stanje).
      await reservations.checkIn(created.id); // 8 sati pre početka
      now = at(3, 14); // 4 sata pre početka
      expect(reservations.cancelReservation(created.id), violates<CancellationDeadlineExpired>());
    });

    test('potvrđena rezervacija bez dolaska je posle roka već otkazana', () async {
      if (testDb == null) return;
      final created = await reservations.createReservation(
        fieldId: FieldId(2), userId: UserId(1), startTime: at(3, 18), endTime: at(3, 19),
      );

      now = at(3, 14);
      expect(reservations.cancelReservation(created.id), violates<InvalidReservationStatus>());
      expect((await reservations.getReservationById(created.id))!.status, ReservationStatus.cancelled);
    });

    test('check-in i automatski završetak posle termina', () async {
      if (testDb == null) return;
      final created = await reservations.createReservation(
        fieldId: FieldId(2), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19),
      );

      now = at(4, 9); // 9 sati pre početka: prozor je otvoren
      final checkedIn = await reservations.checkIn(created.id);
      expect(checkedIn.isCheckedIn, isTrue);

      now = at(4, 20); // termin je istekao
      final after = await reservations.getReservationById(created.id);
      expect(after!.status, ReservationStatus.completed);
    });

    test('nepotvrđena rezervacija postaje otkazana kada prođe rok', () async {
      if (testDb == null) return;
      final created = await reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19),
      );

      now = at(4, 13, 30); // rok je bio u 13:00
      final after = await reservations.getReservationById(created.id);
      expect(after!.status, ReservationStatus.cancelled);
    });

    test('promena nepostojeće rezervacije', () async {
      if (testDb == null) return;
      expect(reservations.cancelReservation(ReservationId(404)), throwsA(isA<EntityNotFound>()));
    });
  });

  group('MySqlSportsFieldRepository', () {
    test('javni katalog sadrži samo aktivne i odobrene terene', () async {
      if (testDb == null) return;

      expect((await fields.getPublicFields()).map((f) => f.name), ['Arena', 'Tenis']);
      expect(await fields.getFields(), hasLength(3));
      expect(await fields.getFieldsByOwner(UserId(3)), hasLength(3));
    });

    test('dodavanje i izmena terena sa slikama', () async {
      if (testDb == null) return;

      final created = await fields.createField(
        ownerId: UserId(3),
        name: 'Basket',
        description: 'Otvoreni teren',
        sport: SportType.basketball,
        address: 'Nemanjina 15',
        city: 'Beograd',
        pricePerHour: 1500,
        contactPhone: '063',
        imageUrls: const ['a.jpg', 'b.jpg'],
        confirmationMode: ConfirmationMode.automatic,
      );
      expect(created.imageUrls, ['a.jpg', 'b.jpg']);
      // Novi teren čeka odobrenje administratora.
      expect((await fields.getPublicFields()).map((f) => f.name), isNot(contains('Basket')));

      final updated = await fields.updateField(
        created.copyWith(pricePerHour: 1800, imageUrls: const ['c.jpg'], isActive: false),
      );
      expect(updated.pricePerHour, 1800);
      expect(updated.imageUrls, ['c.jpg']);
      expect(updated.isActive, isFalse);
      expect(updated.description, 'Otvoreni teren'); // TEXT kolona
    });
  });

  group('MySqlFieldScheduleRepository', () {
    test('zamena radnog vremena i čitanje kao TimeOfDay', () async {
      if (testDb == null) return;

      await schedules.replaceSchedules(FieldId(1), const [
        FieldSchedule(
          fieldId: FieldId(1),
          dayOfWeek: WeekDay.saturday,
          opensAt: TimeOfDay(hour: 9, minute: 30),
          closesAt: TimeOfDay(hour: 21, minute: 0),
        ),
      ]);

      final result = await schedules.getSchedules(FieldId(1));
      expect(result, hasLength(1));
      expect(result.single.dayOfWeek, WeekDay.saturday);
      expect(result.single.opensAt.totalMinutes, 9 * 60 + 30);
      expect(result.single.closesAt.totalMinutes, 21 * 60);
    });

    test('blokade se filtriraju po intervalu', () async {
      if (testDb == null) return;
      await schedules.addBlockedPeriod(
          BlockedPeriod(fieldId: FieldId(1), startTime: at(5, 12), endTime: at(5, 14)));
      await schedules.addBlockedPeriod(
          BlockedPeriod(fieldId: FieldId(1), startTime: at(8, 12), endTime: at(8, 14)));

      expect(await schedules.getBlockedPeriods(FieldId(1)), hasLength(2));
      expect(await schedules.getBlockedPeriods(FieldId(1), from: at(5, 0), to: at(6, 0)), hasLength(1));
    });
  });

  group('MySqlUserRepository', () {
    test('čita korisnike po id-u, e-pošti i ulozi', () async {
      if (testDb == null) return;

      final ana = await users.getUserById(UserId(1));
      expect(ana!.fullName, 'Ana Anić');
      expect(ana.dateOfBirth, DateTime.utc(2000, 1, 1));
      expect((await users.getUserByEmail('ANA@example.com'))!.id, UserId(1));
      expect(await users.getUserByEmail('nema@example.com'), isNull);
      expect(await users.getUsers(role: UserRole.user), hasLength(2));
      expect(await users.getUsers(), hasLength(4));
    });
  });
}
