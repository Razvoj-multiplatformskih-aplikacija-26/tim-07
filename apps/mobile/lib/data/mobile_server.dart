import 'package:api_client/api_client.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// Svi izvori podataka mobilne aplikacije, preko jednog HTTP klijenta.
///
/// Ovo je jedino mesto koje zna da podaci dolaze sa servera. Ekrani i Bloc-ovi
/// primaju portove iz domena, pa isti kod radi i nad lažnim repozitorijumima
/// u testovima i u demo režimu.
final class MobileServer {
  MobileServer._(this.api)
    : reservations = HttpReservationRepository(api),
      fields = HttpFieldRepository(api),
      schedules = HttpScheduleRepository(api),
      availability = HttpAvailabilityRepository(api),
      auth = HttpSessionRepository(api);

  /// Klijent koji drži token prijave i adresu servera.
  final ApiClient api;

  final ReservationRepository reservations;
  final SportsFieldRepository fields;
  final FieldScheduleRepository schedules;
  final AvailabilityRepository availability;
  final AuthRepository auth;

  /// Server na [baseUri]. [session] čuva token između pokretanja (u
  /// aplikaciji `createSessionStore()`); [httpClient] zamenjuje mrežu u testovima.
  factory MobileServer.connect({
    required Uri baseUri,
    SessionStore? session,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  }) => MobileServer._(
    ApiClient(
      baseUri: baseUri,
      session: session,
      httpClient: httpClient,
      timeout: timeout,
    ),
  );

  void close() => api.close();
}
