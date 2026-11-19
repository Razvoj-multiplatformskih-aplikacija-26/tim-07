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

  /// Blokira teren u periodu.
  ///
  /// Implementacija proverava `validateBlockedPeriod` i baca
  /// `BlockedPeriodRuleViolation` (npr. blokada preko potvrđene rezervacije).
  /// Vraća sačuvanu blokadu sa identifikatorom.
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period);

  /// Uklanja blokadu terena, pa termini ponovo mogu da se rezervišu.
  /// Baca `EntityNotFound` kada te blokade nema na tom terenu.
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id);
}
