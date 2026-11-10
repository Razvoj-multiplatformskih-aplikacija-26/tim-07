import '../enums.dart';
import '../ids.dart';
import '../models/sports_field.dart';

/// Ugovor za pristup sportskim terenima.
///
/// Kao i [ReservationRepository], ne zna za HTTP ni bazu: server ga
/// implementira nad MySQL-om, a klijenti nad serverom ili u memoriji.
abstract interface class SportsFieldRepository {
  /// Svi tereni (za administratora).
  Future<List<SportsField>> getFields();

  /// Tereni koje vidi javnost: aktivni i odobreni.
  Future<List<SportsField>> getPublicFields();

  /// Tereni jednog vlasnika, i neaktivni i neodobreni.
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId);

  /// Jedan teren ili null ako ne postoji.
  Future<SportsField?> getFieldById(FieldId id);

  /// Dodaje novi teren; administrator ga zatim odobrava.
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  });

  /// Upisuje izmenjene podatke postojećeg terena (vlasnik se ne menja).
  Future<SportsField> updateField(SportsField field);
}
