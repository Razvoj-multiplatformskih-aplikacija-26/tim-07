
// Terenzo — zajednički domenski modeli i pravila.
// Ovaj paket koriste mobilna i backoffice aplikacija.
// Ne zavisi od Flutter-a.

// Tipizirani ID-jevi.
export 'src/ids.dart';

// Enum tipovi.
export 'src/enums.dart';

// Domenski modeli.
export 'src/models/app_user.dart';
export 'src/models/sports_field.dart';
export 'src/models/reservation.dart';
export 'src/models/field_schedule.dart';
export 'src/models/review.dart';

// T06 — Statusi i automatski životni ciklus.
export 'src/rules/reservation_transitions.dart';
export 'src/rules/reservation_auto_status.dart';

// T07 — Tipizirane greške i validacije.
export 'src/rules/reservation_validation_error.dart';
export 'src/rules/reservation_validation.dart';

// T08 — Preklapanje, blokirani termini i radno vreme.
export 'src/rules/reservation_overlap.dart';
export 'src/rules/reservation_blocked_periods.dart';
export 'src/rules/reservation_working_hours.dart';

// T09 — Repository port za rezervacije.
export 'src/repositories/reservation_repository.dart';
