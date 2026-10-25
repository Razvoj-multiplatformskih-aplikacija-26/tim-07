import 'package:blocs/blocs.dart';

import 'mobile_demo_data.dart';
import 'mobile_fake_repository.dart';

MobileFakeReservationRepository createMobileRepository({
  DateTime Function()? clock,
  Duration delay = const Duration(milliseconds: 600),
}) {
  final now = clock?.call() ?? DateTime.now();

  final store = FakeReservationRepository(
    reservations: MobileDemoData.createReservations(now: now),
    fields: MobileDemoData.fields,
    schedules: MobileDemoData.schedules,
    clock: clock,
  );

  return MobileFakeReservationRepository(store, delay: delay);
}
