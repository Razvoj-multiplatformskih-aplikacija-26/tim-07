
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final start = DateTime(2026, 11, 10, 14);
  final end = DateTime(2026, 11, 10, 16);

  Reservation createReservation({
    required int id,
    required int fieldId,
    required int userId,
    required DateTime startTime,
    required DateTime endTime,
    ReservationStatus status = ReservationStatus.confirmed,
  }) {
    return Reservation(
      id: ReservationId(id),
      fieldId: FieldId(fieldId),
      userId: UserId(userId),
      startTime: startTime,
      endTime: endTime,
      totalPrice: 3000,
      status: status,
      createdAt: DateTime(2026, 11, 1),
    );
  }

  group('Preklapanje vremenskih intervala', () {
    test('intervali koji se preklapaju', () {
      expect(
        doTimeRangesOverlap(
          firstStart: start,
          firstEnd: end,
          secondStart: DateTime(2026, 11, 10, 15),
          secondEnd: DateTime(2026, 11, 10, 17),
        ),
        isTrue,
      );
    });

    test('intervali koji se dodiruju se ne preklapaju', () {
      expect(
        doTimeRangesOverlap(
          firstStart: start,
          firstEnd: end,
          secondStart: end,
          secondEnd: DateTime(2026, 11, 10, 18),
        ),
        isFalse,
      );
    });
  });

  group('Konflikti rezervacija', () {
    test('isti teren u isto vreme nije dozvoljen', () {
      final existing = [
        createReservation(
          id: 1,
          fieldId: 1,
          userId: 1,
          startTime: start,
          endTime: end,
        ),
      ];

      expect(
        hasReservationOverlap(
          fieldId: FieldId(1),
          userId: UserId(2),
          startTime: DateTime(2026, 11, 10, 15),
          endTime: DateTime(2026, 11, 10, 17),
          existingReservations: existing,
        ),
        isTrue,
      );
    });

    test('isti korisnik ne moze rezervisati dva terena istovremeno', () {
      final existing = [
        createReservation(
          id: 1,
          fieldId: 1,
          userId: 1,
          startTime: start,
          endTime: end,
        ),
      ];

      expect(
        hasReservationOverlap(
          fieldId: FieldId(2),
          userId: UserId(1),
          startTime: DateTime(2026, 11, 10, 15),
          endTime: DateTime(2026, 11, 10, 17),
          existingReservations: existing,
        ),
        isTrue,
      );
    });

    test('razliciti korisnici na razlicitim terenima su dozvoljeni', () {
      final existing = [
        createReservation(
          id: 1,
          fieldId: 1,
          userId: 1,
          startTime: start,
          endTime: end,
        ),
      ];

      expect(
        hasReservationOverlap(
          fieldId: FieldId(2),
          userId: UserId(2),
          startTime: start,
          endTime: end,
          existingReservations: existing,
        ),
        isFalse,
      );
    });

    test('otkazane rezervacije ne blokiraju termin', () {
      final existing = [
        createReservation(
          id: 1,
          fieldId: 1,
          userId: 1,
          startTime: start,
          endTime: end,
          status: ReservationStatus.cancelled,
        ),
      ];

      expect(
        hasReservationOverlap(
          fieldId: FieldId(1),
          userId: UserId(2),
          startTime: start,
          endTime: end,
          existingReservations: existing,
        ),
        isFalse,
      );
    });

    test('pending rezervacije blokiraju termin', () {
      final existing = [
        createReservation(
          id: 1,
          fieldId: 1,
          userId: 1,
          startTime: start,
          endTime: end,
          status: ReservationStatus.pending,
        ),
      ];

      expect(
        hasReservationOverlap(
          fieldId: FieldId(1),
          userId: UserId(2),
          startTime: start,
          endTime: end,
          existingReservations: existing,
        ),
        isTrue,
      );
    });
  });
}
