import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';
import '../models/reservation.dart';
import '../models/slot_availability.dart';
import 'reservation_overlap.dart';

List<SlotAvailability> availableSlots({
  required FieldId fieldId,
  required DateTime localDay,
  required Iterable<FieldSchedule> schedules,
  required Iterable<Reservation> reservations,
  Iterable<BlockedPeriod> blockedPeriods = const [],
  required DateTime now,
  Duration slotLength = const Duration(hours: 1),
}) {
  final day = DateTime(localDay.year, localDay.month, localDay.day);
  final weekday = WeekDay.values[day.weekday - 1];
  FieldSchedule? schedule;
  for (final candidate in schedules) {
    if (candidate.fieldId == fieldId && candidate.dayOfWeek == weekday) {
      schedule = candidate;
    }
  }
  if (schedule == null || !schedule.isOpen) return const [];

  final opens = DateTime(day.year, day.month, day.day, schedule.opensAt.hour, schedule.opensAt.minute);
  final closes = DateTime(day.year, day.month, day.day, schedule.closesAt.hour, schedule.closesAt.minute);

  bool overlaps(DateTime start, DateTime end, DateTime otherStart, DateTime otherEnd) =>
      doTimeRangesOverlap(firstStart: start, firstEnd: end, secondStart: otherStart, secondEnd: otherEnd);

  final slots = <SlotAvailability>[];
  for (var start = opens; !start.add(slotLength).isAfter(closes); start = start.add(slotLength)) {
    final end = start.add(slotLength);
    final state = !start.isAfter(now)
        ? SlotState.past
        : blockedPeriods.any((b) => b.fieldId == fieldId && overlaps(start, end, b.startTime, b.endTime))
            ? SlotState.blocked
            : reservations.any((r) => r.fieldId == fieldId && r.isActive && overlaps(start, end, r.startTime, r.endTime))
                ? SlotState.taken
                : SlotState.free;
    slots.add(SlotAvailability(startTime: start, endTime: end, state: state));
  }
  return slots;
}
