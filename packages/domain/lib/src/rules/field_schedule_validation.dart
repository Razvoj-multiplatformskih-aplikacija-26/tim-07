import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';

sealed class ScheduleValidationError {
  final WeekDay? day;

  const ScheduleValidationError(this.day);
}

final class InvalidTimeOfDay extends ScheduleValidationError {
  const InvalidTimeOfDay(WeekDay super.day);
}

final class OpeningAfterClosing extends ScheduleValidationError {
  const OpeningAfterClosing(WeekDay super.day);
}

final class DuplicateScheduleDay extends ScheduleValidationError {
  const DuplicateScheduleDay(WeekDay super.day);
}

final class ScheduleForOtherField extends ScheduleValidationError {
  const ScheduleForOtherField(WeekDay super.day);
}

final class ScheduleRuleViolation implements Exception {
  final ScheduleValidationError error;

  const ScheduleRuleViolation(this.error);

  @override
  String toString() => 'ScheduleRuleViolation(${error.runtimeType}, ${error.day?.name})';
}

bool _isValidTime(TimeOfDay time) =>
    time.hour >= 0 && time.hour <= 23 && time.minute >= 0 && time.minute <= 59;

ScheduleValidationError? validateFieldSchedule({
  required FieldId fieldId,
  required Iterable<FieldSchedule> schedules,
}) {
  final seen = <WeekDay>{};

  for (final schedule in schedules) {
    final day = schedule.dayOfWeek;

    if (schedule.fieldId != fieldId) {
      return ScheduleForOtherField(day);
    }

    if (!seen.add(day)) {
      return DuplicateScheduleDay(day);
    }

    if (!schedule.isOpen) {
      continue;
    }

    if (!_isValidTime(schedule.opensAt) || !_isValidTime(schedule.closesAt)) {
      return InvalidTimeOfDay(day);
    }

    if (schedule.opensAt.totalMinutes >= schedule.closesAt.totalMinutes) {
      return OpeningAfterClosing(day);
    }
  }

  return null;
}
