import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';

extension AvailabilitySlotMapping on AvailabilitySlot {
  SlotDto toDto() => SlotDto(
    startTime: startTime.toUtc(),
    endTime: endTime.toUtc(),
    state: slotStateToCode(state),
  );
}

extension AvailabilitySlotListMapping on Iterable<AvailabilitySlot> {
  /// Odgovor servera za jedan dan terena. [date] je kalendarski dan terena.
  AvailabilityDto toDto({required FieldId fieldId, required DateTime date}) =>
      AvailabilityDto(
        fieldId: fieldId.value,
        date: dateToJson(date.year, date.month, date.day),
        slots: [for (final slot in this) slot.toDto()],
      );
}

extension SlotDtoMapping on SlotDto {
  /// Baca [UnknownCodeException] za stanje termina koje ova verzija ne poznaje.
  /// Trenuci su UTC; ko ih prikazuje pretvara ih u lokalno vreme.
  AvailabilitySlot toDomain() => AvailabilitySlot(
    startTime: startTime,
    endTime: endTime,
    state: requireKnown(slotStateFromCode(state), 'slotState', state),
  );
}

extension AvailabilityDtoMapping on AvailabilityDto {
  List<AvailabilitySlot> toDomain() => [
    for (final slot in slots) slot.toDomain(),
  ];
}
