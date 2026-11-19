import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';
import '../models/reservation.dart';
import 'reservation_auto_status.dart';
import 'reservation_working_hours.dart';

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

/// Novo radno vreme ne obuhvata rezervacije koje već postoje. [count] je broj
/// takvih rezervacija (na čekanju ili potvrđenih, koje još nisu završene), a
/// [firstStart] početak najranije. `day` je dan u nedelji te rezervacije.
final class ScheduleConflictsWithReservations extends ScheduleValidationError {
  final int count;
  final DateTime firstStart;

  ScheduleConflictsWithReservations({
    required this.count,
    required this.firstStart,
  }) : super(WeekDay.values[firstStart.weekday - 1]);
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

/// Radno vreme se ne sme promeniti tako da postojeća rezervacija ostane van
/// njega: korisnik je dobio termin pod starim uslovima, a vlasnik ga ne može
/// tiho da pretvori u termin kada teren ne radi.
///
/// Računaju se rezervacije ovog terena koje su na čekanju ili potvrđene (posle
/// `resolveReservationStatus`, pa se automatski otkazane ne računaju) i koje se
/// još nisu završile. Ako je neka od njih van novog radnog vremena, vraća se
/// [ScheduleConflictsWithReservations] sa brojem i najranijom; inače `null`.
///
/// Vlasnik rešava sukob tako što rezervacije otkaže (ili odbije), ili zadrži
/// radno vreme koje ih obuhvata. Prošle, otkazane i završene rezervacije ne
/// smetaju.
ScheduleValidationError? validateScheduleAgainstReservations({
  required FieldId fieldId,
  required Iterable<FieldSchedule> schedules,
  required Iterable<Reservation> reservations,
  required DateTime now,
}) {
  final conflicts = <Reservation>[];

  for (final reservation in reservations) {
    if (reservation.fieldId != fieldId) continue;

    final status = resolveReservationStatus(reservation, now);
    final active =
        status == ReservationStatus.pending ||
        status == ReservationStatus.confirmed;
    if (!active || !reservation.endTime.isAfter(now)) continue;

    final fits = isReservationWithinWorkingHours(
      fieldId: fieldId,
      startTime: reservation.startTime,
      endTime: reservation.endTime,
      schedules: schedules,
    );
    if (!fits) conflicts.add(reservation);
  }

  if (conflicts.isEmpty) return null;

  conflicts.sort((a, b) => a.startTime.compareTo(b.startTime));
  return ScheduleConflictsWithReservations(
    count: conflicts.length,
    firstStart: conflicts.first.startTime,
  );
}
