import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';

extension FieldOccupancyMapping on FieldOccupancy {
  FieldOccupancyDto toDto() => FieldOccupancyDto(
    fieldId: fieldId.value,
    fieldName: fieldName,
    availableMinutes: availableMinutes,
    bookedMinutes: bookedMinutes,
    completedCount: completedCount,
    cancelledCount: cancelledCount,
    activeCount: activeCount,
  );
}

extension FieldOccupancyDtoMapping on FieldOccupancyDto {
  FieldOccupancy toDomain() => FieldOccupancy(
    fieldId: FieldId(fieldId),
    fieldName: fieldName,
    availableMinutes: availableMinutes,
    bookedMinutes: bookedMinutes,
    completedCount: completedCount,
    cancelledCount: cancelledCount,
    activeCount: activeCount,
  );
}

extension OccupancyReportMapping on OccupancyReport {
  OccupancyReportDto toDto() => OccupancyReportDto(
    period: statsPeriodToCode(period.kind),
    from: period.from.toUtc(),
    to: period.to.toUtc(),
    fields: [for (final field in fields) field.toDto()],
  );
}

extension OccupancyReportDtoMapping on OccupancyReportDto {
  /// Granice perioda se uzimaju onakve kakve je server poslao, ne računaju se
  /// po zoni uređaja, pa klijent u drugoj zoni prikazuje isti period.
  OccupancyReport toDomain() => OccupancyReport(
    period: StatsPeriod.exact(
      requireKnown(statsPeriodFromCode(period), 'statsPeriod', period),
      from,
      to,
    ),
    fields: [for (final field in fields) field.toDomain()],
  );
}
