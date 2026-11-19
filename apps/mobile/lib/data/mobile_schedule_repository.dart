import 'package:blocs/blocs.dart';

import 'mobile_demo_data.dart';

/// Radno vreme i blokade terena iz memorije, dok mobilna aplikacija nema
/// server (T52). Zamenjuje se `HttpScheduleRepository`-jem bez izmene Bloc-a i ekrana.
FakeFieldScheduleRepository createMobileScheduleRepository() {
  return FakeFieldScheduleRepository(schedules: MobileDemoData.schedules);
}
