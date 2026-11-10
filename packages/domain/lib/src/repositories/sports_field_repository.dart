import '../enums.dart';
import '../ids.dart';
import '../models/sports_field.dart';

abstract interface class SportsFieldRepository {
  Future<List<SportsField>> getFields();

  Future<List<SportsField>> getPublicFields();

  Future<List<SportsField>> getFieldsByOwner(UserId ownerId);

  Future<SportsField?> getFieldById(FieldId id);

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

  Future<SportsField> updateField(SportsField field);
}
