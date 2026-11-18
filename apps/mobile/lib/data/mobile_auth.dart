import 'package:blocs/blocs.dart';

import 'mobile_demo_data.dart';

/// Prijava nad demo nalozima, dok mobilna aplikacija ne dobije server (T52).
/// Zamenjuje se `HttpSessionRepository`-jem bez izmene Bloc-a i ekrana.
FakeAuthRepository createMobileAuthRepository({
  Duration delay = const Duration(milliseconds: 400),
  DateTime Function()? clock,
}) {
  return FakeAuthRepository(
    accounts: MobileDemoData.accounts,
    delay: delay,
    clock: clock,
  );
}
