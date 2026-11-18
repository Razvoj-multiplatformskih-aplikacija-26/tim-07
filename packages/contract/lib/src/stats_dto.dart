import 'json.dart';

/// Zauzetost jednog terena u periodu. Na mreži idu minuti, a procenat
/// zaokružuje klijent (odluka 14 u docs/kt2-decisions.md).
final class FieldOccupancyDto {
  final int fieldId;
  final String fieldName;
  final int availableMinutes;
  final int bookedMinutes;
  final int completedCount;
  final int cancelledCount;
  final int activeCount;

  const FieldOccupancyDto({
    required this.fieldId,
    required this.fieldName,
    required this.availableMinutes,
    required this.bookedMinutes,
    required this.completedCount,
    required this.cancelledCount,
    required this.activeCount,
  });

  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'fieldName': fieldName,
    'availableMinutes': availableMinutes,
    'bookedMinutes': bookedMinutes,
    'completedCount': completedCount,
    'cancelledCount': cancelledCount,
    'activeCount': activeCount,
  };

  factory FieldOccupancyDto.fromJson(Map<String, Object?> json) =>
      FieldOccupancyDto(
        fieldId: jsonInt(json, 'fieldId'),
        fieldName: jsonString(json, 'fieldName'),
        availableMinutes: jsonInt(json, 'availableMinutes'),
        bookedMinutes: jsonInt(json, 'bookedMinutes'),
        completedCount: jsonInt(json, 'completedCount'),
        cancelledCount: jsonInt(json, 'cancelledCount'),
        activeCount: jsonInt(json, 'activeCount'),
      );
}

/// Odgovor `GET /stats/occupancy?period=week|month&day=YYYY-MM-DD`.
final class OccupancyReportDto {
  /// Kod iz `StatsPeriodCodes`.
  final String period;

  /// Granice perioda kao trenuci u UTC (od, do), `do` nije uključeno.
  final DateTime from;
  final DateTime to;
  final List<FieldOccupancyDto> fields;

  OccupancyReportDto({
    required this.period,
    required this.from,
    required this.to,
    required List<FieldOccupancyDto> fields,
  }) : fields = List.unmodifiable(fields);

  Map<String, Object?> toJson() => {
    'period': period,
    'from': instantToJson(from),
    'to': instantToJson(to),
    'fields': [for (final field in fields) field.toJson()],
  };

  factory OccupancyReportDto.fromJson(Map<String, Object?> json) =>
      OccupancyReportDto(
        period: jsonString(json, 'period'),
        from: jsonInstant(json, 'from'),
        to: jsonInstant(json, 'to'),
        fields: [
          for (final field in jsonObjects(json, 'fields'))
            FieldOccupancyDto.fromJson(field),
        ],
      );
}
