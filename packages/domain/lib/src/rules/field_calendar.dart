import '../enums.dart';
import '../ids.dart';
import '../models/field_schedule.dart';
import '../models/reservation.dart';
import 'reservation_auto_status.dart';
import 'reservation_overlap.dart';

/// Jedan red u kalendaru terena: slobodan termin, rezervacija ili blokada.
sealed class CalendarEntry {
  DateTime get startTime;
  DateTime get endTime;
}

/// Slobodan termin. [isPast] je tačno kada je termin već počeo, pa više ne
/// može da se rezerviše (isto kao `SlotState.past`).
final class CalendarFreeSlot implements CalendarEntry {
  @override
  final DateTime startTime;
  @override
  final DateTime endTime;
  final bool isPast;

  const CalendarFreeSlot({
    required this.startTime,
    required this.endTime,
    required this.isPast,
  });

  @override
  bool operator ==(Object other) =>
      other is CalendarFreeSlot &&
      other.startTime == startTime &&
      other.endTime == endTime &&
      other.isPast == isPast;

  @override
  int get hashCode => Object.hash(startTime, endTime, isPast);
}

/// Rezervacija u kalendaru. [status] je stanje u trenutku crtanja
/// (`resolveReservationStatus`): rezervacija na čekanju kojoj je istekao rok
/// se već vidi kao otkazana i ne ulazi u kalendar.
final class CalendarReservation implements CalendarEntry {
  final Reservation reservation;
  final ReservationStatus status;

  const CalendarReservation({required this.reservation, required this.status});

  @override
  DateTime get startTime => reservation.startTime;

  @override
  DateTime get endTime => reservation.endTime;

  @override
  bool operator ==(Object other) =>
      other is CalendarReservation &&
      other.reservation.id == reservation.id &&
      other.reservation.startTime == reservation.startTime &&
      other.reservation.endTime == reservation.endTime &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(reservation.id, reservation.startTime, reservation.endTime, status);
}

/// Blokada terena (održavanje, događaj) u kalendaru.
final class CalendarBlock implements CalendarEntry {
  final BlockedPeriod period;

  const CalendarBlock(this.period);

  @override
  DateTime get startTime => period.startTime;

  @override
  DateTime get endTime => period.endTime;

  @override
  bool operator ==(Object other) =>
      other is CalendarBlock &&
      other.period.id == period.id &&
      other.period.startTime == period.startTime &&
      other.period.endTime == period.endTime &&
      other.period.reason == period.reason;

  @override
  int get hashCode =>
      Object.hash(period.id, period.startTime, period.endTime, period.reason);
}

/// Jedan teren u jednom danu: redovi kalendara po vremenu.
final class FieldCalendarDay {
  final FieldId fieldId;

  /// Kalendarski dan (ponoć).
  final DateTime date;

  /// `false` kada teren tog dana ne radi ili nema radno vreme; tada nema redova.
  final bool isOpen;

  final List<CalendarEntry> entries;

  FieldCalendarDay({
    required this.fieldId,
    required this.date,
    required this.isOpen,
    required Iterable<CalendarEntry> entries,
  }) : entries = List.unmodifiable(entries);

  @override
  bool operator ==(Object other) =>
      other is FieldCalendarDay &&
      other.fieldId == fieldId &&
      other.date == date &&
      other.isOpen == isOpen &&
      _sameEntries(other.entries, entries);

  @override
  int get hashCode => Object.hash(fieldId, date, isOpen, entries.length);

  static bool _sameEntries(List<CalendarEntry> a, List<CalendarEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Kalendar jednog terena za jedan dan.
///
/// Redovi idu po radnom vremenu terena tog dana u nedelji, termin po termin
/// (dužine [slotLength]); isto radno vreme koristi `calculateAvailability`, pa
/// kalendar i aplikacija za korisnike nikad ne prikazuju različite termine.
///
/// - Rezervacija koja pokriva termin ulazi u kalendar jednom, sa svojim
///   početkom i krajem. Otkazane rezervacije nisu u kalendaru: njihov termin je
///   slobodan.
/// - Blokada koja pokriva termin ulazi jednom, sa svojim opsegom. Ako se
///   rezervacija na čekanju i blokada preklapaju, termin pripada rezervaciji,
///   jer je vlasnik mora videti da bi je odbio.
/// - Ostalo je slobodno.
///
/// [date] je kalendarski dan; koriste se samo godina, mesec i dan.
FieldCalendarDay buildFieldCalendarDay({
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

  final day = DateTime(date.year, date.month, date.day);
  final weekday = WeekDay.values[day.weekday - 1];

  FieldSchedule? schedule;
  for (final candidate in schedules) {
    if (candidate.fieldId == fieldId && candidate.dayOfWeek == weekday) {
      schedule = candidate;
      break;
    }
  }

  final opens = schedule?.opensAt.totalMinutes ?? 0;
  final closes = schedule?.closesAt.totalMinutes ?? 0;
  if (schedule == null || !schedule.isOpen || closes <= opens) {
    return FieldCalendarDay(
      fieldId: fieldId,
      date: day,
      isOpen: false,
      entries: const [],
    );
  }

  DateTime at(int minutes) => DateTime(day.year, day.month, day.day, 0, minutes);

  final visible = <CalendarReservation>[
    for (final reservation in reservations)
      if (reservation.fieldId == fieldId)
        if (resolveReservationStatus(reservation, now)
            case final status when status != ReservationStatus.cancelled)
          CalendarReservation(reservation: reservation, status: status),
  ];
  final blocks = [
    for (final period in blockedPeriods)
      if (period.fieldId == fieldId) period,
  ];

  final entries = <CalendarEntry>[];
  final shownReservations = <ReservationId>{};
  final shownBlocks = <BlockedPeriod>{};

  for (var start = opens; start + step <= closes; start += step) {
    final startTime = at(start);
    final endTime = at(start + step);

    CalendarReservation? reservation;
    for (final candidate in visible) {
      if (doTimeRangesOverlap(
        firstStart: startTime,
        firstEnd: endTime,
        secondStart: candidate.startTime,
        secondEnd: candidate.endTime,
      )) {
        reservation = candidate;
        break;
      }
    }
    if (reservation != null) {
      if (shownReservations.add(reservation.reservation.id)) {
        entries.add(reservation);
      }
      continue;
    }

    BlockedPeriod? block;
    for (final candidate in blocks) {
      if (doTimeRangesOverlap(
        firstStart: startTime,
        firstEnd: endTime,
        secondStart: candidate.startTime,
        secondEnd: candidate.endTime,
      )) {
        block = candidate;
        break;
      }
    }
    if (block != null) {
      if (shownBlocks.add(block)) entries.add(CalendarBlock(block));
      continue;
    }

    entries.add(
      CalendarFreeSlot(
        startTime: startTime,
        endTime: endTime,
        isPast: !startTime.isAfter(now),
      ),
    );
  }

  return FieldCalendarDay(
    fieldId: fieldId,
    date: day,
    isOpen: true,
    entries: entries,
  );
}
