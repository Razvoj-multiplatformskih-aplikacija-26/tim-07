
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ReservationState Equatable', () {
    test('dva Initial stanja su jednaka', () {
      expect(
        const ReservationInitial(),
        equals(const ReservationInitial()),
      );
    });

    test('dva Loading stanja su jednaka', () {
      expect(
        const ReservationLoading(),
        equals(const ReservationLoading()),
      );
    });

    test('dva Empty stanja su jednaka', () {
      expect(
        const ReservationEmpty(),
        equals(const ReservationEmpty()),
      );
    });

    test('Error stanja sa istom porukom su jednaka', () {
      expect(
        const ReservationError('Network error'),
        equals(const ReservationError('Network error')),
      );
    });

    test('Error stanja sa razlicitim porukama nisu jednaka', () {
      expect(
        const ReservationError('Network error'),
        isNot(equals(const ReservationError('Timeout'))),
      );
    });

    test('Loaded stanja sa praznim listama su jednaka', () {
      expect(
        const ReservationLoaded([]),
        equals(const ReservationLoaded([])),
      );
    });

    test('Loaded stanja sa razlicitim rezervacijama nisu jednaka', () {
      final reservation1 = _createReservation(1);
      final reservation2 = _createReservation(2);

      expect(
        ReservationLoaded([reservation1]),
        isNot(equals(ReservationLoaded([reservation2]))),
      );
    });

    test('Loaded stanja sa istom rezervacijom su jednaka', () {
      final reservation = _createReservation(1);

      expect(
        ReservationLoaded([reservation]),
        equals(ReservationLoaded([reservation])),
      );
    });

    test('razliciti tipovi stanja nisu jednaki', () {
      expect(
        const ReservationLoading(),
        isNot(equals(const ReservationEmpty())),
      );
    });
  });
}

Reservation _createReservation(int id) {
  return Reservation(
    id: ReservationId(id),
    fieldId: FieldId(1),
    userId: UserId(1),
    startTime: DateTime(2026, 11, 10, 18),
    endTime: DateTime(2026, 11, 10, 20),
    totalPrice: 3000,
    status: ReservationStatus.confirmed,
    createdAt: DateTime(2026, 11, 1),
  );
}
