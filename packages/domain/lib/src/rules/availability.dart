import '../enums.dart';
import '../ids.dart';
import '../models/availability.dart';
import '../models/field_schedule.dart';
import '../models/reservation.dart';
import 'reservation_blocked_periods.dart';
import 'reservation_overlap.dart';

/// Termini terena za jedan dan, sa stanjem svakog.
///
/// Isto pravilo koriste server (odgovor na `GET /fields/:id/availability`) i
/// lažni repozitorijum u klijentu, pa ekran nikad ne izmišlja termine: dani i
/// sati dolaze iz radnog vremena terena, a stanje iz rezervacija i blokada.
///
/// - Termini idu od otvaranja do zatvaranja tog dana u nedelji, redom, svaki
///   dug [slotLength]. Ostatak koji ne stane u celi termin se izostavlja.
/// - Dan bez rasporeda, dan koji je označen kao neradni i raspored koji se
///   završava pre početka daju praznu listu.
/// - Stanje po prioritetu: `past` (termin je već počeo), `blocked` (blokada
///   terena), `taken` (aktivna rezervacija bilo kog korisnika), inače `free`.
///   Slobodan termin je upravo onaj koji `validateReservationSlot` propušta
///   za korisnika koji nema druge rezervacije.
///
/// [date] je kalendarski dan; koriste se samo godina, mesec i dan. Termini su
/// u istom okviru kao [date]: UTC dan daje UTC termine, lokalni lokalne. Pozivalac
/// mora da bude dosledan sa radnim vremenom (server radi u zoni objekta).
List<AvailabilitySlot> calculateAvailability({
  required FieldId fieldId,
  required DateTime date,
  required Iterable<FieldSchedule> schedules,
  required Iterable<Reservation> reservations,
  Iterable<BlockedPeriod> blockedPeriods = const [],
  required DateTime now,
  Duration slotLength = const Duration(hours: 1),
}) {
  final step = slotLength.inMinutes;
  if (step <= 0) {
    throw ArgumentError.value(slotLength, 'slotLength', 'Mora biti bar minut.');
  }

  final weekday = WeekDay.values[date.weekday - 1];

  FieldSchedule? schedule;
  for (final candidate in schedules) {
    if (candidate.fieldId == fieldId && candidate.dayOfWeek == weekday) {
      schedule = candidate;
      break;
    }
  }

  if (schedule == null || !schedule.isOpen) return const [];

  final opens = schedule.opensAt.totalMinutes;
  final closes = schedule.closesAt.totalMinutes;
  if (closes <= opens) return const [];

  DateTime at(int minutes) => date.isUtc
      ? DateTime.utc(date.year, date.month, date.day, 0, minutes)
      : DateTime(date.year, date.month, date.day, 0, minutes);

  final active = [
    for (final reservation in reservations)
      if (reservation.fieldId == fieldId && reservation.isActive) reservation,
  ];
  final blocks = blockedPeriods.toList();

  final slots = <AvailabilitySlot>[];
  for (var start = opens; start + step <= closes; start += step) {
    final startTime = at(start);
    final endTime = at(start + step);

    final SlotState state;
    if (!startTime.isAfter(now)) {
      state = SlotState.past;
    } else if (hasBlockedPeriodOverlap(
      fieldId: fieldId,
      startTime: startTime,
      endTime: endTime,
      blockedPeriods: blocks,
    )) {
      state = SlotState.blocked;
    } else if (active.any(
      (reservation) => doTimeRangesOverlap(
        firstStart: startTime,
        firstEnd: endTime,
        secondStart: reservation.startTime,
        secondEnd: reservation.endTime,
      ),
    )) {
      state = SlotState.taken;
    } else {
      state = SlotState.free;
    }

    slots.add(
      AvailabilitySlot(startTime: startTime, endTime: endTime, state: state),
    );
  }

  return slots;
}
