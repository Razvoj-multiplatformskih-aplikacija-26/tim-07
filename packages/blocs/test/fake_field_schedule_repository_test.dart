import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

const field = FieldId(1);
const other = FieldId(2);
final before = DateTime(2026, 11, 19, 8);

FieldSchedule day(
  FieldId id,
  WeekDay weekday, {
  int opens = 8,
  int closes = 22,
}) => FieldSchedule(
  fieldId: id,
  dayOfWeek: weekday,
  opensAt: TimeOfDay(hour: opens, minute: 0),
  closesAt: TimeOfDay(hour: closes, minute: 0),
);

BlockedPeriod block(FieldId id, int fromHour, int toHour) => BlockedPeriod(
  fieldId: id,
  startTime: DateTime(2026, 11, 20, fromHour),
  endTime: DateTime(2026, 11, 20, toHour),
);

void main() {
  group('radno vreme', () {
    test('vraća samo raspored traženog terena', () async {
      final repository = FakeFieldScheduleRepository(
        schedules: [day(field, WeekDay.monday), day(other, WeekDay.monday)],
      );

      final result = await repository.getSchedules(field);

      expect(result, hasLength(1));
      expect(result.single.fieldId, field);
    });

    test('zamena menja ceo raspored terena, a tuđi ostaje', () async {
      final repository = FakeFieldScheduleRepository(
        schedules: [
          day(field, WeekDay.monday),
          day(field, WeekDay.tuesday),
          day(other, WeekDay.monday),
        ],
      );

      await repository.replaceSchedules(field, [
        day(field, WeekDay.friday, opens: 10, closes: 14),
      ]);

      final mine = await repository.getSchedules(field);
      expect(mine.map((d) => d.dayOfWeek), [WeekDay.friday]);
      expect(mine.single.closesAt.hour, 14);
      expect(await repository.getSchedules(other), hasLength(1));
    });

    test('pogrešan raspored se odbija, a stari ostaje netaknut', () async {
      final repository = FakeFieldScheduleRepository(
        schedules: [day(field, WeekDay.monday)],
      );

      await expectLater(
        repository.replaceSchedules(field, [
          day(field, WeekDay.friday, opens: 20, closes: 8),
        ]),
        throwsA(isA<ScheduleRuleViolation>()),
      );
      await expectLater(
        repository.replaceSchedules(field, [
          day(field, WeekDay.monday),
          day(field, WeekDay.monday),
        ]),
        throwsA(isA<ScheduleRuleViolation>()),
      );

      final kept = await repository.getSchedules(field);
      expect(kept.map((d) => d.dayOfWeek), [WeekDay.monday]);
    });
  });

  group('blokirani periodi', () {
    test('samo blokade traženog terena', () async {
      final repository = FakeFieldScheduleRepository(
        blockedPeriods: [block(field, 10, 12), block(other, 10, 12)],
      );

      expect(await repository.getBlockedPeriods(field), hasLength(1));
    });

    test('opseg vraća blokade koje ga dodiruju', () async {
      final repository = FakeFieldScheduleRepository(
        blockedPeriods: [
          block(field, 8, 10),
          block(field, 12, 14),
          block(field, 16, 18),
        ],
      );

      final result = await repository.getBlockedPeriods(
        field,
        from: DateTime(2026, 11, 20, 9),
        to: DateTime(2026, 11, 20, 13),
      );

      // 08-10 i 12-14 se preklapaju sa 09-13, 16-18 ne.
      expect(result.map((b) => b.startTime.hour), [8, 12]);
    });

    test(
      'blokada koja se završava tačno na početku opsega se ne računa',
      () async {
        final repository = FakeFieldScheduleRepository(
          blockedPeriods: [block(field, 8, 10)],
        );

        final result = await repository.getBlockedPeriods(
          field,
          from: DateTime(2026, 11, 20, 10),
        );

        expect(result, isEmpty);
      },
    );

    test('dodata blokada se vidi, sa identifikatorom', () async {
      final repository = FakeFieldScheduleRepository(clock: () => before);

      final added = await repository.addBlockedPeriod(block(field, 10, 12));

      expect(added.fieldId, field);
      expect(added.id, isNotNull);
      expect(await repository.getBlockedPeriods(field), [added]);
    });
  });

  group('blokiranje terena (T61)', () {
    Reservation reservation(
      FieldId onField,
      int hour,
      ReservationStatus status,
    ) => Reservation(
      id: const ReservationId(1),
      fieldId: onField,
      userId: const UserId(7),
      startTime: DateTime(2026, 11, 20, hour),
      endTime: DateTime(2026, 11, 20, hour + 1),
      totalPrice: 1000,
      status: status,
      createdAt: DateTime(2026, 11, 1),
    );

    FakeFieldScheduleRepository repositoryWith(List<Reservation> existing) =>
        FakeFieldScheduleRepository(
          reservations: FakeReservationRepository(
            reservations: existing,
            clock: () => before,
          ),
          clock: () => before,
        );

    test(
      'početne blokade dobijaju identifikatore, nove sledeći po redu',
      () async {
        final repository = FakeFieldScheduleRepository(
          blockedPeriods: [block(field, 10, 12), block(field, 14, 16)],
          clock: () => before,
        );

        final initial = await repository.getBlockedPeriods(field);
        final added = await repository.addBlockedPeriod(block(field, 18, 20));

        expect(initial.map((b) => b.id?.value), [1, 2]);
        expect(added.id, const BlockedPeriodId(3));
      },
    );

    test(
      'blokada preko potvrđene rezervacije se odbija i ne upisuje',
      () async {
        final repository = repositoryWith([
          reservation(field, 11, ReservationStatus.confirmed),
        ]);

        await expectLater(
          repository.addBlockedPeriod(block(field, 10, 12)),
          throwsA(
            isA<BlockedPeriodRuleViolation>().having(
              (e) => e.error,
              'error',
              isA<BlockOverlapsConfirmedReservation>(),
            ),
          ),
        );
        expect(await repository.getBlockedPeriods(field), isEmpty);
      },
    );

    test(
      'rezervacija na čekanju, tuđeg terena ili otkazana ne smeta',
      () async {
        final repository = repositoryWith([
          reservation(field, 10, ReservationStatus.pending),
          reservation(other, 11, ReservationStatus.confirmed),
          reservation(field, 12, ReservationStatus.cancelled),
        ]);

        final saved = await repository.addBlockedPeriod(block(field, 10, 14));

        expect(saved.id, isNotNull);
      },
    );

    test('kraj pre početka i prošli period se odbijaju', () async {
      final repository = FakeFieldScheduleRepository(clock: () => before);

      await expectLater(
        repository.addBlockedPeriod(block(field, 12, 10)),
        throwsA(isA<BlockedPeriodRuleViolation>()),
      );
      await expectLater(
        repository.addBlockedPeriod(
          BlockedPeriod(
            fieldId: field,
            startTime: DateTime(2026, 11, 18, 10),
            endTime: DateTime(2026, 11, 18, 12),
          ),
        ),
        throwsA(isA<BlockedPeriodRuleViolation>()),
      );
    });

    test('brisanje uklanja blokadu samo sa njenog terena', () async {
      final repository = FakeFieldScheduleRepository(clock: () => before);
      final saved = await repository.addBlockedPeriod(block(field, 10, 12));

      await expectLater(
        repository.removeBlockedPeriod(other, saved.id!),
        throwsA(isA<EntityNotFound>()),
      );
      expect(await repository.getBlockedPeriods(field), hasLength(1));

      await repository.removeBlockedPeriod(field, saved.id!);
      expect(await repository.getBlockedPeriods(field), isEmpty);
      await expectLater(
        repository.removeBlockedPeriod(field, saved.id!),
        throwsA(isA<EntityNotFound>()),
      );
    });
  });
}
