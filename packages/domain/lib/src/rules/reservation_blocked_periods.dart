
import '../ids.dart';
import '../models/field_schedule.dart';
import 'reservation_overlap.dart';

/// Proverava da li se željeni termin rezervacije
/// preklapa sa nekim blokiranim periodom terena.
///
/// Blokirani periodi drugih terena se ignorišu.
bool hasBlockedPeriodOverlap({
  required FieldId fieldId,
  required DateTime startTime,
  required DateTime endTime,
  required Iterable<BlockedPeriod> blockedPeriods,
}) {
  for (final blockedPeriod in blockedPeriods) {
    // Proveravamo samo blokade traženog terena.
    if (blockedPeriod.fieldId != fieldId) {
      continue;
    }

    if (doTimeRangesOverlap(
      firstStart: startTime,
      firstEnd: endTime,
      secondStart: blockedPeriod.startTime,
      secondEnd: blockedPeriod.endTime,
    )) {
      return true;
    }
  }

  return false;
}
