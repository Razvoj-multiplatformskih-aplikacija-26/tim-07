import '../ids.dart';
import '../models/field_schedule.dart';

/// Ugovor za radno vreme i blokirane periode terena.
abstract interface class FieldScheduleRepository {
  /// Radno vreme terena po danima. Dan bez rasporeda znači zatvoreno.
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId);

  /// Zamenjuje celo nedeljno radno vreme terena.
  Future<void> replaceSchedules(FieldId fieldId, List<FieldSchedule> schedules);

  /// Blokirani periodi terena koji se seku sa intervalom [from, to).
  ///
  /// Bez granica vraća sve blokade terena.
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  });

  /// Dodaje blokadu (održavanje, događaj).
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period);
}
