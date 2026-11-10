import '../ids.dart';

enum StatsPeriodKind { week, month }

final class StatsPeriod {
  final StatsPeriodKind kind;
  final DateTime from;
  final DateTime to;

  const StatsPeriod._(this.kind, this.from, this.to);

  factory StatsPeriod.weekOf(DateTime day) {
    final local = day.toLocal();
    final monday = DateTime(local.year, local.month, local.day - (local.weekday - DateTime.monday));
    return StatsPeriod._(
      StatsPeriodKind.week,
      monday,
      DateTime(monday.year, monday.month, monday.day + 7),
    );
  }

  factory StatsPeriod.monthOf(DateTime day) {
    final local = day.toLocal();
    return StatsPeriod._(
      StatsPeriodKind.month,
      DateTime(local.year, local.month),
      DateTime(local.year, local.month + 1),
    );
  }

  factory StatsPeriod.of(StatsPeriodKind kind, DateTime day) => switch (kind) {
        StatsPeriodKind.week => StatsPeriod.weekOf(day),
        StatsPeriodKind.month => StatsPeriod.monthOf(day),
      };
}

final class FieldOccupancy {
  final FieldId fieldId;
  final String fieldName;
  final int availableMinutes;
  final int bookedMinutes;
  final int completedCount;
  final int cancelledCount;
  final int activeCount;

  const FieldOccupancy({
    required this.fieldId,
    required this.fieldName,
    required this.availableMinutes,
    required this.bookedMinutes,
    required this.completedCount,
    required this.cancelledCount,
    required this.activeCount,
  });

  int get occupancyPercent =>
      availableMinutes == 0 ? 0 : (bookedMinutes * 100 / availableMinutes).round();
}

final class OccupancyReport {
  final StatsPeriod period;
  final List<FieldOccupancy> fields;

  OccupancyReport({required this.period, required List<FieldOccupancy> fields})
      : fields = List.unmodifiable(fields);

  int get availableMinutes => fields.fold(0, (sum, f) => sum + f.availableMinutes);

  int get bookedMinutes => fields.fold(0, (sum, f) => sum + f.bookedMinutes);

  int get completedCount => fields.fold(0, (sum, f) => sum + f.completedCount);

  int get cancelledCount => fields.fold(0, (sum, f) => sum + f.cancelledCount);

  int get activeCount => fields.fold(0, (sum, f) => sum + f.activeCount);

  int get occupancyPercent =>
      availableMinutes == 0 ? 0 : (bookedMinutes * 100 / availableMinutes).round();
}
