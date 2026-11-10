import '../ids.dart';
import '../models/field_schedule.dart';

abstract interface class FieldScheduleRepository {
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId);

  Future<void> replaceSchedules(FieldId fieldId, List<FieldSchedule> schedules);

  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  });

  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period);
}
