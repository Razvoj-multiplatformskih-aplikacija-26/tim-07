import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

import 'backoffice_demo_data.dart';
import 'backoffice_fake_repository.dart';

BackofficeFakeReservationRepository createBackofficeRepository({
  DateTime Function()? clock,
  Duration delay = const Duration(milliseconds: 600),
}) {
  final now = clock?.call() ?? DateTime.now();

  final store = FakeReservationRepository(
    reservations: BackofficeDemoData.createReservations(now: now),
    fields: BackofficeDemoData.fields,
    schedules: BackofficeDemoData.schedules,
    blockedPeriods: BackofficeDemoData.blockedPeriods,
    users: BackofficeDemoData.users,
    clock: clock,
  );

  return BackofficeFakeReservationRepository(store, delay: delay);
}

/// Tereni iz memorije, dok backoffice nema server (T53).
SportsFieldRepository createBackofficeFieldRepository() {
  return FakeSportsFieldRepository(fields: BackofficeDemoData.fields);
}

/// Radno vreme i blokade iz memorije. Blokada se proverava nad rezervacijama
/// koje vidi i tabela rezervacija, pa ne može preko potvrđene rezervacije.
FieldScheduleRepository createBackofficeScheduleRepository({
  required BackofficeFakeReservationRepository reservations,
  DateTime Function()? clock,
}) {
  return FakeFieldScheduleRepository(
    schedules: BackofficeDemoData.schedules,
    blockedPeriods: BackofficeDemoData.blockedPeriods,
    reservations: reservations.store,
    clock: clock,
  );
}
