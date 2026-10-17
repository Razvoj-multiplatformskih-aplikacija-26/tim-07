import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';

/// Proverava da li je željeni termin rezervacije
/// u potpunosti unutar radnog vremena terena.
///
/// Za svaki dan koji rezervacija obuhvata proverava
/// odgovarajući raspored rada.
///
/// Podržava termine koji prelaze preko ponoći,
/// pod uslovom da je teren otvoren u oba dana.
///
/// Ako raspored za neki dan ne postoji,
/// smatra se da je teren tog dana zatvoren.
bool isReservationWithinWorkingHours({
  required FieldId fieldId,
  required DateTime startTime,
  required DateTime endTime,
  required Iterable<FieldSchedule> schedules,
}) {
  if (!endTime.isAfter(startTime)) {
    return false;
  }

  final fieldSchedules = schedules
      .where((schedule) => schedule.fieldId == fieldId)
      .toList();

  var current = startTime;

  while (current.isBefore(endTime)) {
    final weekday = WeekDay.values[current.weekday - 1];

    FieldSchedule? schedule;

    for (final candidate in fieldSchedules) {
      if (candidate.dayOfWeek == weekday) {
        schedule = candidate;
        break;
      }
    }

    if (schedule == null || !schedule.isOpen) {
      return false;
    }

    final dayStart = DateTime(
      current.year,
      current.month,
      current.day,
    );

    final nextDay = DateTime(
      current.year,
      current.month,
      current.day + 1,
    );

    final segmentEnd = endTime.isBefore(nextDay)
        ? endTime
        : nextDay;

    final openingTime = dayStart.add(
      Duration(minutes: schedule.opensAt.totalMinutes),
    );

    final closingTime = dayStart.add(
      Duration(minutes: schedule.closesAt.totalMinutes),
    );

    // Raspored mora imati pozitivan vremenski interval.
    if (!closingTime.isAfter(openingTime)) {
      return false;
    }

    // Ceo deo rezervacije za ovaj dan mora
    // biti unutar radnog vremena.
    if (current.isBefore(openingTime) ||
        segmentEnd.isAfter(closingTime)) {
      return false;
    }

    current = segmentEnd;
  }

  return true;
}
