import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';

import 'mobile_demo_data.dart';
import 'mobile_fake_repository.dart';

/// Slobodni termini iz memorije sa kašnjenjem i simulacijom greške, dok
/// mobilna aplikacija nema server (T52). Zamenjuje se `HttpAvailabilityRepository`-jem
/// bez izmene Bloc-a i ekrana.
class MobileFakeAvailabilityRepository implements AvailabilityRepository {
  final AvailabilityRepository _store;
  final Duration delay;

  bool _failNext = false;

  MobileFakeAvailabilityRepository(
    this._store, {
    this.delay = const Duration(milliseconds: 600),
  });

  /// Sledeći zahtev puca kao da server ne radi.
  void failNextRequest() => _failNext = true;

  @override
  Future<List<AvailabilitySlot>> getAvailability({
    required FieldId fieldId,
    required DateTime date,
  }) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (_failNext) {
      _failNext = false;
      throw const ServerUnreachableException();
    }

    return _store.getAvailability(fieldId: fieldId, date: date);
  }
}

/// Termini se računaju iz istih rezervacija koje vidi `reservations`, pa
/// rezervacija napravljena u aplikaciji odmah zauzima termin.
MobileFakeAvailabilityRepository createMobileAvailabilityRepository({
  required MobileFakeReservationRepository reservations,
  Duration delay = const Duration(milliseconds: 600),
  DateTime Function()? clock,
}) {
  return MobileFakeAvailabilityRepository(
    FakeAvailabilityRepository(
      reservations: reservations.store,
      schedules: MobileDemoData.schedules,
      clock: clock,
    ),
    delay: delay,
  );
}
