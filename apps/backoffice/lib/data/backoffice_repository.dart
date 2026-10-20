import 'package:blocs/blocs.dart';

import 'backoffice_demo_data.dart';

/// Pravi poseban FakeRepository za backoffice.
///
/// Backoffice ima svoju instancu repozitorijuma i svoje demo
/// podatke, nezavisno od mobilne aplikacije. Kada bude postojao
/// pravi API repozitorijum, menja se samo ova funkcija.
FakeReservationRepository createBackofficeRepository({
  DateTime Function()? clock,
}) {
  final now = clock?.call() ?? DateTime.now();

  return FakeReservationRepository(
    reservations: BackofficeDemoData.createReservations(now: now),
    fields: BackofficeDemoData.fields,
    schedules: BackofficeDemoData.schedules,
    blockedPeriods: BackofficeDemoData.blockedPeriods,
    clock: clock,
  );
}
