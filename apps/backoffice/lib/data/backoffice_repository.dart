import 'package:blocs/blocs.dart';

import 'backoffice_demo_data.dart';

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
