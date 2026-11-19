import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';

import 'api_client.dart';

/// Slobodni termini terena preko HTTP-a. Termine računa server (isto pravilo
/// iz `domain` kao u klijentu), a javni su: rade i bez prijave (odluka 8).
final class HttpAvailabilityRepository implements AvailabilityRepository {
  const HttpAvailabilityRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<AvailabilitySlot>> getAvailability({
    required FieldId fieldId,
    required DateTime date,
  }) async {
    final json = await _api.get(
      ApiPaths.availability(fieldId.value),
      query: {ApiQuery.date: dateToJson(date.year, date.month, date.day)},
    );

    return readBody(json, (o) {
      final slots = AvailabilityDto.fromJson(o).toDomain();

      // Server šalje trenutke u UTC; ekran ih prikazuje u lokalnom vremenu.
      return [
        for (final slot in slots)
          AvailabilitySlot(
            startTime: slot.startTime.toLocal(),
            endTime: slot.endTime.toLocal(),
            state: slot.state,
          ),
      ];
    });
  }
}
