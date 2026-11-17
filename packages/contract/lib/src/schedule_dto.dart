import 'json.dart';

/// Jedan red slobodnih/zauzetih termina u odgovoru o dostupnosti.
final class SlotDto {
  final DateTime startTime;
  final DateTime endTime;

  /// Kod iz `SlotStateCodes`. Odgovor ne kaže ko je rezervisao termin.
  final String state;

  const SlotDto({
    required this.startTime,
    required this.endTime,
    required this.state,
  });

  Map<String, Object?> toJson() => {
    'startTime': instantToJson(startTime),
    'endTime': instantToJson(endTime),
    'state': state,
  };

  factory SlotDto.fromJson(Map<String, Object?> json) => SlotDto(
    startTime: jsonInstant(json, 'startTime'),
    endTime: jsonInstant(json, 'endTime'),
    state: jsonString(json, 'state'),
  );
}

/// Odgovor `GET /fields/:id/availability?date=YYYY-MM-DD`.
final class AvailabilityDto {
  final int fieldId;

  /// Lokalni datum terena, `YYYY-MM-DD`.
  final String date;
  final List<SlotDto> slots;

  AvailabilityDto({
    required this.fieldId,
    required this.date,
    required List<SlotDto> slots,
  }) : slots = List.unmodifiable(slots);

  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'date': date,
    'slots': [for (final slot in slots) slot.toJson()],
  };

  factory AvailabilityDto.fromJson(Map<String, Object?> json) =>
      AvailabilityDto(
        fieldId: jsonInt(json, 'fieldId'),
        date: jsonString(json, 'date'),
        slots: [
          for (final slot in jsonObjects(json, 'slots')) SlotDto.fromJson(slot),
        ],
      );
}

/// Radno vreme terena za jedan dan, lokalno vreme objekta (`HH:mm`).
final class ScheduleDayDto {
  /// Kod iz `WeekDayCodes`.
  final String dayOfWeek;
  final ClockTime opensAt;
  final ClockTime closesAt;
  final bool isOpen;

  const ScheduleDayDto({
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.isOpen = true,
  });

  Map<String, Object?> toJson() => {
    'dayOfWeek': dayOfWeek,
    'opensAt': opensAt.toJson(),
    'closesAt': closesAt.toJson(),
    'isOpen': isOpen,
  };

  factory ScheduleDayDto.fromJson(Map<String, Object?> json) => ScheduleDayDto(
    dayOfWeek: jsonString(json, 'dayOfWeek'),
    opensAt: jsonClockTime(json, 'opensAt'),
    closesAt: jsonClockTime(json, 'closesAt'),
    isOpen: json['isOpen'] == null ? true : jsonBool(json, 'isOpen'),
  );
}

/// Radno vreme po danima: odgovor `GET` i telo `PUT /fields/:id/schedule`.
final class ScheduleDto {
  final List<ScheduleDayDto> days;

  ScheduleDto({required List<ScheduleDayDto> days})
    : days = List.unmodifiable(days);

  Map<String, Object?> toJson() => {
    'days': [for (final day in days) day.toJson()],
  };

  factory ScheduleDto.fromJson(Map<String, Object?> json) => ScheduleDto(
    days: [
      for (final day in jsonObjects(json, 'days')) ScheduleDayDto.fromJson(day),
    ],
  );
}

/// Blokirani period terena (održavanje, događaj).
final class BlockedPeriodDto {
  final int fieldId;
  final DateTime startTime;
  final DateTime endTime;
  final String? reason;

  const BlockedPeriodDto({
    required this.fieldId,
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'startTime': instantToJson(startTime),
    'endTime': instantToJson(endTime),
    'reason': ?reason,
  };

  factory BlockedPeriodDto.fromJson(Map<String, Object?> json) =>
      BlockedPeriodDto(
        fieldId: jsonInt(json, 'fieldId'),
        startTime: jsonInstant(json, 'startTime'),
        endTime: jsonInstant(json, 'endTime'),
        reason: jsonOptionalString(json, 'reason'),
      );
}

/// Telo zahteva `POST /fields/:id/blocked-periods` (teren je u adresi).
final class CreateBlockedPeriodRequestDto {
  final DateTime startTime;
  final DateTime endTime;
  final String? reason;

  const CreateBlockedPeriodRequestDto({
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  Map<String, Object?> toJson() => {
    'startTime': instantToJson(startTime),
    'endTime': instantToJson(endTime),
    'reason': ?reason,
  };

  factory CreateBlockedPeriodRequestDto.fromJson(Map<String, Object?> json) =>
      CreateBlockedPeriodRequestDto(
        startTime: jsonInstant(json, 'startTime'),
        endTime: jsonInstant(json, 'endTime'),
        reason: jsonOptionalString(json, 'reason'),
      );
}
