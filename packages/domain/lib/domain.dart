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
export 'src/models/occupancy.dart';

// T06 — Statusi i automatski životni ciklus.
export 'src/rules/reservation_transitions.dart';
export 'src/rules/reservation_auto_status.dart';

// T07 — Tipizirane greške i validacije.
export 'src/rules/reservation_validation_error.dart';
export 'src/rules/reservation_validation.dart';
export 'src/rules/domain_exceptions.dart';
export 'src/rules/field_approval.dart';
export 'src/rules/field_schedule_validation.dart';
export 'src/rules/occupancy.dart';

// T08 — Preklapanje, blokirani termini i radno vreme.
export 'src/rules/reservation_overlap.dart';
export 'src/rules/reservation_blocked_periods.dart';
export 'src/rules/reservation_working_hours.dart';
export 'src/rules/reservation_price.dart';

// T09 — Repository port za rezervacije.
export 'src/repositories/reservation_repository.dart';

export 'src/repositories/sports_field_repository.dart';
export 'src/repositories/field_schedule_repository.dart';
export 'src/repositories/user_repository.dart';
export 'src/repositories/statistics_repository.dart';
