import 'package:domain/domain.dart';

/// Radno vreme i blokirani periodi terena u memoriji, bez servera. Ista pravila
/// kao u serverskom repozitorijumu: radno vreme proverava `validateFieldSchedule`
/// (pogrešan raspored ostavlja stari netaknut), a blokadu `validateBlockedPeriod`
/// (ne sme preko potvrđene rezervacije).
///
/// Zamenljiv sa HTTP repozitorijumom bez izmene Bloc-ova i ekrana.
final class FakeFieldScheduleRepository implements FieldScheduleRepository {
  final List<FieldSchedule> _schedules;
  final List<BlockedPeriod> _blockedPeriods;
  var _nextBlockId = 1;

  /// Izvor rezervacija za proveru blokade. Bez njega blokada ne zna za rezervacije.
  final ReservationRepository? reservations;
  final DateTime Function() _clock;

  FakeFieldScheduleRepository({
    Iterable<FieldSchedule> schedules = const [],
    Iterable<BlockedPeriod> blockedPeriods = const [],
    this.reservations,
    DateTime Function()? clock,
  }) : _schedules = List.of(schedules),
       _blockedPeriods = [],
       _clock = clock ?? DateTime.now {
    // Početne blokade dobijaju identifikatore, kao da ih je dodelio server.
    for (final period in blockedPeriods) {
      _blockedPeriods.add(_withId(period));
    }
  }

  BlockedPeriod _withId(BlockedPeriod period) {
    final existing = period.id;
    if (existing != null) {
      if (existing.value >= _nextBlockId) _nextBlockId = existing.value + 1;
      return period;
    }
    return BlockedPeriod(
      id: BlockedPeriodId(_nextBlockId++),
      fieldId: period.fieldId,
      startTime: period.startTime,
      endTime: period.endTime,
      reason: period.reason,
    );
  }

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
    final now = _clock();

    // Potvrđena rezervacija koja je u međuvremenu sama otkazana ili završena ne smeta.
    final source = reservations;
    final onField = source == null
        ? const <Reservation>[]
        : await source.getReservationsByField(period.fieldId);
    final current = [
      for (final reservation in onField)
        reservation.copyWith(status: resolveReservationStatus(reservation, now)),
    ];

    final error = validateBlockedPeriod(
      fieldId: period.fieldId,
      startTime: period.startTime,
      endTime: period.endTime,
      now: now,
      reservations: current,
    );
    if (error != null) throw BlockedPeriodRuleViolation(error);

    final saved = _withId(
      BlockedPeriod(
        fieldId: period.fieldId,
        startTime: period.startTime,
        endTime: period.endTime,
        reason: period.reason,
      ),
    );
    _blockedPeriods.add(saved);
    return saved;
  }

  @override
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id) async {
    final index = _blockedPeriods.indexWhere(
      (period) => period.id == id && period.fieldId == fieldId,
    );
    if (index == -1) throw EntityNotFound('blocked period', id.value);

    _blockedPeriods.removeAt(index);
  }
}
