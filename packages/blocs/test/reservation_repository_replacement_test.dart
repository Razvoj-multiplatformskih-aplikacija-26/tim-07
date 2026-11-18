
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

/// Druga implementacija repository interfejsa.
/// Nije nasledjena iz FakeReservationRepository.
final class TestReservationRepository implements ReservationRepository {
  final List<Reservation> reservations;

  TestReservationRepository(this.reservations);

  @override
  Future<List<Reservation>> getReservations() async {
    return List.unmodifiable(reservations);
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    return reservations.where((r) => r.userId == userId).toList();
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    return reservations.where((r) => r.fieldId == fieldId).toList();
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    for (final reservation in reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }
    return null;
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    throw UnimplementedError('Test repository ne podrzava kreiranje.');
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    throw UnimplementedError('Test repository ne podrzava promenu statusa.');
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    throw UnimplementedError('Test repository ne podrzava check-in.');
  }

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async {
    throw UnimplementedError('Test repository ne podrzava otkazivanje.');
  }
}

void main() {
  group('ReservationBloc - repository replacement', () {
    test('radi sa drugom implementacijom repository interfejsa', () async {
      final reservations = DemoData.createReservations(
        now: DateTime(2026, 10, 17, 12),
      );

      // Ovde koristimo TestReservationRepository umesto FakeRepository.
      final ReservationRepository repository =
      TestReservationRepository(reservations);

      // Bloc ne mora da se menja.
      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationLoaded>().having(
                (state) => state.reservations.length,
            'broj rezervacija',
            3,
          ),
        ]),
      );

      await bloc.close();
    });

    test('radi i kada druga implementacija vrati praznu listu', () async {
      final ReservationRepository repository =
      TestReservationRepository([]);

      final bloc = ReservationBloc(repository: repository);

      bloc.add(const ReservationsRequested());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ReservationLoading>(),
          isA<ReservationEmpty>(),
        ]),
      );

      await bloc.close();
    });
  });
}
