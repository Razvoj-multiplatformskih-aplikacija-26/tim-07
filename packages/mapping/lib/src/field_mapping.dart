import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';

extension SportsFieldMapping on SportsField {
  FieldDto toDto() => FieldDto(
    id: id.value,
    ownerId: ownerId.value,
    name: name,
    description: description,
    sport: sportToCode(sport),
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: confirmationModeToCode(confirmationMode),
    isActive: isActive,
    approvalStatus: approvalStatusToCode(approvalStatus),
    rejectionReason: rejectionReason,
  );

  /// Telo zahteva za izmenu terena (obrazac u backoffice-u).
  SaveFieldRequestDto toSaveRequest() => SaveFieldRequestDto(
    name: name,
    description: description,
    sport: sportToCode(sport),
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: confirmationModeToCode(confirmationMode),
    isActive: isActive,
  );
}

extension FieldDtoMapping on FieldDto {
  /// Baca [UnknownCodeException] za nepoznat sport, način potvrde ili odobrenost.
  SportsField toDomain() => SportsField(
    id: FieldId(id),
    ownerId: UserId(ownerId),
    name: name,
    description: description,
    sport: requireKnown(sportFromCode(sport), 'sport', sport),
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: requireKnown(
      confirmationModeFromCode(confirmationMode),
      'confirmationMode',
      confirmationMode,
    ),
    isActive: isActive,
    approvalStatus: requireKnown(
      approvalStatusFromCode(approvalStatus),
      'approvalStatus',
      approvalStatus,
    ),
    rejectionReason: rejectionReason,
  );

  SportsField? toDomainOrNull() {
    try {
      return toDomain();
    } on UnknownCodeException {
      return null;
    }
  }
}

extension FieldDtoListMapping on Iterable<FieldDto> {
  /// Preskače terene sa nepoznatim kodom (npr. nov sport koji aplikacija ne zna).
  List<SportsField> toDomainKnown() => [
    for (final dto in this) ?dto.toDomainOrNull(),
  ];
}

extension SaveFieldRequestMapping on SaveFieldRequestDto {
  SportType toSport() => requireKnown(sportFromCode(sport), 'sport', sport);

  ConfirmationMode toConfirmationMode() => requireKnown(
    confirmationModeFromCode(confirmationMode),
    'confirmationMode',
    confirmationMode,
  );

  /// Primenjuje izmene na postojeći teren. Vlasnik i odobrenost se ne menjaju
  /// iz zahteva: njih određuje server (`approvalStatusAfterOwnerEdit`).
  SportsField applyTo(SportsField existing) => existing.copyWith(
    name: name,
    description: description,
    sport: toSport(),
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: toConfirmationMode(),
    isActive: isActive,
  );
}

extension SportsDtoMapping on SportsDto {
  /// Sportovi koje ova verzija poznaje, redosledom sa servera. Nepoznat sport
  /// se preskače, jer za njega aplikacija nema ni naziv ni ikonicu.
  List<SportType> toDomainKnown() => [
    for (final code in sports) ?sportFromCode(code),
  ];
}

extension SportsToDto on Iterable<SportType> {
  SportsDto toDto() =>
      SportsDto(sports: [for (final sport in this) sportToCode(sport)]);
}

extension FieldScheduleMapping on FieldSchedule {
  ScheduleDayDto toDto() => ScheduleDayDto(
    dayOfWeek: weekDayToCode(dayOfWeek),
    opensAt: ClockTime(opensAt.hour, opensAt.minute),
    closesAt: ClockTime(closesAt.hour, closesAt.minute),
    isOpen: isOpen,
  );
}

extension FieldScheduleListMapping on Iterable<FieldSchedule> {
  ScheduleDto toDto() =>
      ScheduleDto(days: [for (final day in this) day.toDto()]);
}

extension ScheduleDayDtoMapping on ScheduleDayDto {
  FieldSchedule toDomain(FieldId fieldId) => FieldSchedule(
    fieldId: fieldId,
    dayOfWeek: requireKnown(weekDayFromCode(dayOfWeek), 'weekDay', dayOfWeek),
    opensAt: TimeOfDay(hour: opensAt.hour, minute: opensAt.minute),
    closesAt: TimeOfDay(hour: closesAt.hour, minute: closesAt.minute),
    isOpen: isOpen,
  );
}

extension ScheduleDtoMapping on ScheduleDto {
  List<FieldSchedule> toDomain(FieldId fieldId) => [
    for (final day in days) day.toDomain(fieldId),
  ];
}

extension BlockedPeriodMapping on BlockedPeriod {
  BlockedPeriodDto toDto() => BlockedPeriodDto(
    id: id?.value,
    fieldId: fieldId.value,
    startTime: startTime,
    endTime: endTime,
    reason: reason,
  );
}

extension BlockedPeriodDtoMapping on BlockedPeriodDto {
  BlockedPeriod toDomain() => BlockedPeriod(
    id: id == null ? null : BlockedPeriodId(id!),
    fieldId: FieldId(fieldId),
    // UTC sa servera, lokalno vreme na ekranu (vidi `ReservationDtoMapping`).
    startTime: startTime.toLocal(),
    endTime: endTime.toLocal(),
    reason: reason,
  );
}

extension CreateBlockedPeriodMapping on CreateBlockedPeriodRequestDto {
  /// Teren je u adresi zahteva, ne u telu.
  BlockedPeriod toDomain(FieldId fieldId) => BlockedPeriod(
    fieldId: fieldId,
    startTime: startTime,
    endTime: endTime,
    reason: reason,
  );
}
