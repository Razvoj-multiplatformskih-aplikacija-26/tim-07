import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';

import 'api_client.dart';
import 'paging.dart';

/// Radno vreme i blokirani periodi terena preko HTTP-a.
/// Menjati ih sme samo vlasnik tog terena; proverava server.
final class HttpScheduleRepository implements FieldScheduleRepository {
  const HttpScheduleRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) async {
    final json = await _api.get(ApiPaths.schedule(fieldId.value));
    return readBody(json, (o) => ScheduleDto.fromJson(o).toDomain(fieldId));
  }

  /// Server menja ceo raspored odjednom (odluka 2), pa se šalju svi dani.
  @override
  Future<void> replaceSchedules(
    FieldId fieldId,
    List<FieldSchedule> schedules,
  ) async {
    await _api.put(
      ApiPaths.schedule(fieldId.value),
      body: schedules.toDto().toJson(),
    );
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(
    FieldId fieldId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.blockedPeriods(fieldId.value),
      query: {
        if (from != null) ApiQuery.from: instantToJson(from),
        if (to != null) ApiQuery.to: instantToJson(to),
      },
      fromJson: BlockedPeriodDto.fromJson,
    );
    return [for (final dto in dtos) dto.toDomain()];
  }

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) async {
    final request = CreateBlockedPeriodRequestDto(
      startTime: period.startTime,
      endTime: period.endTime,
      reason: period.reason,
    );
    final json = await _api.post(
      ApiPaths.blockedPeriods(period.fieldId.value),
      body: request.toJson(),
    );
    return readBody(json, (o) => BlockedPeriodDto.fromJson(o).toDomain());
  }

  /// Blokada se briše sa terena na adresi, pa tuđa ne može da se obriše preko pogrešnog terena.
  @override
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id) async {
    await _api.delete(ApiPaths.blockedPeriod(fieldId.value, id.value));
  }
}
