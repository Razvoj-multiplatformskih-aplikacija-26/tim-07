import 'package:domain/domain.dart';

/// Radno vreme i blokirani periodi terena u memoriji, bez servera. Radno vreme
/// proverava isto pravilo kao serverski repozitorijum (`validateFieldSchedule`),
/// a pogrešan raspored ostavlja stari netaknut.
///
/// Zamenljiv sa HTTP repozitorijumom bez izmene Bloc-ova i ekrana.
final class FakeFieldScheduleRepository implements FieldScheduleRepository {
  final List<FieldSchedule> _schedules;
  final List<BlockedPeriod> _blockedPeriods;

  FakeFieldScheduleRepository({
    Iterable<FieldSchedule> schedules = const [],
    Iterable<BlockedPeriod> blockedPeriods = const [],
  }) : _schedules = List.of(schedules),
       _blockedPeriods = List.of(blockedPeriods);

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) async => [
    for (final schedule in _schedules)
      if (schedule.fieldId == fieldId) schedule,
  ];

  @override
  Future<void> replaceSchedules(
    FieldId fieldId,
    List<FieldSchedule> schedules,
  ) async {
    final error = validateFieldSchedule(fieldId: fieldId, schedules: schedules);
    if (error != null) throw ScheduleRuleViolation(error);

    _schedules
      ..removeWhere((schedule) => schedule.fieldId == fieldId)
      ..addAll(schedules);
  }

  /// Blokade terena koje se preklapaju sa `[from, to)`; bez granica, sve.
  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) async => [
    for (final period in _blockedPeriods)
      if (period.fieldId == fieldId &&
          (to == null || period.startTime.isBefore(to)) &&
          (from == null || period.endTime.isAfter(from)))
        period,
  ];

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) async {
    _blockedPeriods.add(period);
    return period;
  }
}
