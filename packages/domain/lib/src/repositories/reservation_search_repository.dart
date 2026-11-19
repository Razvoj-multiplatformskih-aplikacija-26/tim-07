import '../models/reservation.dart';
import '../models/reservation_query.dart';

/// Ugovor za tabelu rezervacija u backoffice-u: jedna strana rezervacija za
/// zadate filtere, pretragu i sortiranje.
///
/// Implementacija vraća samo rezervacije koje pozivalac sme da vidi (vlasnik
/// svojih terena) i primenjuje upit pravilom `searchReservations`.
abstract interface class ReservationSearchRepository {
  Future<PagedResult<Reservation>> searchReservations(ReservationQuery query);
}
