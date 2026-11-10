import '../enums.dart';
import '../models/field_schedule.dart';
import '../models/occupancy.dart';
import '../models/reservation.dart';
import '../models/sports_field.dart';

typedef _Interval = ({DateTime start, DateTime end});

FieldOccupancy calculateFieldOccupancy({
  required SportsField field,
  required StatsPeriod period,
  required Iterable<FieldSchedule> schedules,
  required Iterable<Reservation> reservations,
  Iterable<BlockedPeriod> blockedPeriods = const [],
}) {
  final fieldReservations = reservations.where((r) => r.fieldId == field.id).toList();
  final blocked = [
    for (final b in blockedPeriods)
      if (b.fieldId == field.id) (start: b.startTime, end: b.endTime),
  ];
  final occupying = [
    for (final r in fieldReservations)
      if (r.status != ReservationStatus.cancelled) (start: r.startTime, end: r.endTime),
  ];

  var available = Duration.zero;
  var booked = Duration.zero;

  for (final window in _openWindows(field, period, schedules)) {
    for (final free in _subtract(window, blocked)) {
      available += _length(free);
      for (final part in _merge(_clipAll(occupying, free))) {
        booked += _length(part);
      }
    }
  }

  bool inPeriod(Reservation r) => !r.startTime.isBefore(period.from) && r.startTime.isBefore(period.to);
  final inside = fieldReservations.where(inPeriod);

  return FieldOccupancy(
    fieldId: field.id,
    fieldName: field.name,
    availableMinutes: available.inMinutes,
    bookedMinutes: booked.inMinutes,
    completedCount: inside.where((r) => r.status == ReservationStatus.completed).length,
    cancelledCount: inside.where((r) => r.status == ReservationStatus.cancelled).length,
    activeCount: inside.where((r) => r.isActive).length,
  );
}

OccupancyReport calculateOccupancyReport({
  required StatsPeriod period,
  required Iterable<SportsField> fields,
  required Iterable<FieldSchedule> schedules,
  required Iterable<Reservation> reservations,
  Iterable<BlockedPeriod> blockedPeriods = const [],
}) {
  final sorted = fields.toList()..sort((a, b) => a.name.compareTo(b.name));
  return OccupancyReport(
    period: period,
    fields: [
      for (final field in sorted)
        calculateFieldOccupancy(
          field: field,
          period: period,
          schedules: schedules,
          reservations: reservations,
          blockedPeriods: blockedPeriods,
        ),
    ],
  );
}

Iterable<_Interval> _openWindows(
  SportsField field,
  StatsPeriod period,
  Iterable<FieldSchedule> schedules,
) sync* {
  final byDay = {
    for (final s in schedules)
      if (s.fieldId == field.id && s.isOpen) s.dayOfWeek: s,
  };
  final from = period.from.toLocal();
  final to = period.to.toLocal();

  for (var day = DateTime(from.year, from.month, from.day);
      day.isBefore(to);
      day = DateTime(day.year, day.month, day.day + 1)) {
    final schedule = byDay[WeekDay.values[day.weekday - 1]];
    if (schedule == null) continue;

    final window = _clip(
      (
        start: DateTime(day.year, day.month, day.day, schedule.opensAt.hour, schedule.opensAt.minute),
        end: DateTime(day.year, day.month, day.day, schedule.closesAt.hour, schedule.closesAt.minute),
      ),
      (start: from, end: to),
    );
    if (window != null) yield window;
  }
}

_Interval? _clip(_Interval interval, _Interval bounds) {
  final start = interval.start.isAfter(bounds.start) ? interval.start : bounds.start;
  final end = interval.end.isBefore(bounds.end) ? interval.end : bounds.end;
  return start.isBefore(end) ? (start: start, end: end) : null;
}

List<_Interval> _clipAll(Iterable<_Interval> intervals, _Interval bounds) => [
      for (final interval in intervals)
        ?_clip(interval, bounds),
    ];

List<_Interval> _merge(List<_Interval> intervals) {
  final sorted = intervals.toList()..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_Interval>[];
  for (final interval in sorted) {
    if (merged.isNotEmpty && !interval.start.isAfter(merged.last.end)) {
      final last = merged.removeLast();
      merged.add((start: last.start, end: interval.end.isAfter(last.end) ? interval.end : last.end));
    } else {
      merged.add(interval);
    }
  }
  return merged;
}

List<_Interval> _subtract(_Interval window, List<_Interval> holes) {
  var pieces = [window];
  for (final hole in _merge(_clipAll(holes, window))) {
    pieces = [
      for (final piece in pieces) ...[
        ?_clip(piece, (start: piece.start, end: hole.start)),
        ?_clip(piece, (start: hole.end, end: piece.end)),
      ],
    ];
  }
  return pieces;
}

Duration _length(_Interval interval) => interval.end.difference(interval.start);
