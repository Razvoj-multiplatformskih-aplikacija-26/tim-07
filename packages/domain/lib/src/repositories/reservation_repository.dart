
import '../enums.dart';
import '../ids.dart';
import '../models/reservation.dart';

/// Ugovor za pristup rezervacijama.
///
/// Ne zavisi od Flutter-a, HTTP-a ili baze podataka.
/// FakeRepository i budući API repozitorijum
/// implementiraće ovaj interfejs.
abstract interface class ReservationRepository {
  /// Vraća sve rezervacije.
  Future<List<Reservation>> getReservations();

  /// Vraća rezervacije određenog korisnika.
  Future<List<Reservation>> getReservationsByUser(UserId userId);

  /// Vraća rezervacije određenog terena.
  Future<List<Reservation>> getReservationsByField(FieldId fieldId);

  /// Vraća jednu rezervaciju ili null ako ne postoji.
  Future<Reservation?> getReservationById(ReservationId id);

  /// Kreira novu rezervaciju.
  ///
  /// Implementacija proverava domenska pravila
  /// pre čuvanja rezervacije.
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  });

  /// Menja status rezervacije.
  ///
  /// Implementacija mora da poštuje dozvoljene
  /// prelaze statusa.
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  });

  /// Beleži check-in korisnika.
  ///
  /// Implementacija mora da proveri vremenski
  /// prozor za check-in.
  Future<Reservation> checkIn(ReservationId reservationId);

  /// Otkazuje rezervaciju.
  ///
  /// Implementacija proverava rok za otkazivanje.
  Future<Reservation> cancelReservation(ReservationId reservationId);
}
