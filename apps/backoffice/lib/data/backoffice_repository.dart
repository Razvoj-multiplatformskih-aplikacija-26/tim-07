import 'package:blocs/blocs.dart';

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
    clock: clock,
  );

  return BackofficeFakeReservationRepository(store, delay: delay);
}
