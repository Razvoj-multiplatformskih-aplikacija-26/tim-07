import '../ids.dart';
import '../models/availability.dart';

/// Ugovor za slobodne termine terena. Ne zna da li iza njega stoji server ili
/// memorija; `AvailabilityBloc` radi isto sa svakom implementacijom.
abstract interface class AvailabilityRepository {
  /// Termini terena za kalendarski dan [date] (koriste se godina, mesec i dan),
  /// redom, sa stanjem svakog. Prazna lista znači da teren tog dana ne radi.
  Future<List<AvailabilitySlot>> getAvailability({
    required FieldId fieldId,
    required DateTime date,
  });
}
