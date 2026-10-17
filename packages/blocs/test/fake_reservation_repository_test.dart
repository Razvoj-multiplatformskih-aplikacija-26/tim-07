
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  late FakeReservationRepository repository;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 10, 17, 12);

    repository = FakeReservationRepository(
      fields: DemoData.fields,
      schedules: DemoData.schedules,
      reservations: DemoData.createReservations(now: now),
      blockedPeriods: DemoData.blockedPeriods,
      clock: () => now,
    );
  });

  group('FakeReservationRepository', () {
    test('ucitava tri demo rezervacije', () async {
      final reservations = await repository.getReservations();

      expect(reservations, hasLength(3));
    });

    test('filtrira rezervacije po korisniku', () async {
      final reservations = await repository.getReservationsByUser(
        UserId(1),
      );

      expect(reservations, hasLength(2));
      expect(
        reservations.every((r) => r.userId == UserId(1)),
        isTrue,
      );
    });

    test('filtrira rezervacije po terenu', () async {
      final reservations = await repository.getReservationsByField(
        FieldId(2),
      );

      expect(reservations, hasLength(1));
    });

    test('pronalazi rezervaciju po ID-u', () async {
      final reservation = await repository.getReservationById(
        ReservationId(1),
      );

      expect(reservation, isNotNull);
      expect(reservation!.fieldId, FieldId(1));
    });

    test('vraca null za nepostojecu rezervaciju', () async {
      final reservation = await repository.getReservationById(
        ReservationId(999),
      );

      expect(reservation, isNull);
    });

    test('kreira novu rezervaciju', () async {
      final start = DateTime(2026, 10, 22, 10);
      final end = DateTime(2026, 10, 22, 12);

      final reservation = await repository.createReservation(
        fieldId: FieldId(1),
        userId: UserId(3),
        startTime: start,
        endTime: end,
      );

      expect(reservation.id, ReservationId(4));
      expect(reservation.totalPrice, 6000);
      expect(reservation.status, ReservationStatus.confirmed);

      final reservations = await repository.getReservations();
      expect(reservations, hasLength(4));
    });

    test('rucno potvrdjivanje kreira pending rezervaciju', () async {
      final reservation = await repository.createReservation(
        fieldId: FieldId(2),
        userId: UserId(3),
        startTime: DateTime(2026, 10, 22, 10),
        endTime: DateTime(2026, 10, 22, 11),
      );

      expect(reservation.status, ReservationStatus.pending);
    });

    test('sprecava preklapanje rezervacija', () async {
      await expectLater(
        repository.createReservation(
          fieldId: FieldId(1),
          userId: UserId(3),
          startTime: DateTime(2026, 10, 18, 19),
          endTime: DateTime(2026, 10, 18, 21),
        ),
        throwsStateError,
      );
    });

    test('sprecava rezervaciju van radnog vremena', () async {
      await expectLater(
        repository.createReservation(
          fieldId: FieldId(1),
          userId: UserId(3),
          startTime: DateTime(2026, 10, 22, 6),
          endTime: DateTime(2026, 10, 22, 7),
        ),
        throwsStateError,
      );
    });

    test('omogucava otkazivanje rezervacije', () async {
      final cancelled = await repository.cancelReservation(
        ReservationId(2),
      );

      expect(cancelled.status, ReservationStatus.cancelled);
    });
  });
}
