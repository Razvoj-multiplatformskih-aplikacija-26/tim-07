import 'package:domain/domain.dart';

/// Tereni u memoriji, bez servera. Ista pravila kao serverski repozitorijum:
/// nov teren čeka odobrenje, izmena vlasnika odbijenog terena ga vraća na
/// čekanje, a odluku administratora određuju dozvoljeni prelazi.
///
/// Zamenljiv sa HTTP repozitorijumom bez izmene Bloc-ova i ekrana.
final class FakeSportsFieldRepository implements SportsFieldRepository {
  final List<SportsField> _fields;
  int _nextId;

  FakeSportsFieldRepository({Iterable<SportsField> fields = const []})
    : _fields = List.of(fields),
      _nextId =
          fields.fold<int>(0, (max, f) => f.id.value > max ? f.id.value : max) +
          1;

  @override
  Future<List<SportsField>> getFields() async => List.unmodifiable(_fields);

  @override
  Future<List<SportsField>> getPublicFields() async => [
    for (final field in _fields)
      if (isFieldPublic(field)) field,
  ];

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async => [
    for (final field in _fields)
      if (field.ownerId == ownerId) field,
  ];

  @override
  Future<SportsField?> getFieldById(FieldId id) async {
    final index = _indexOf(id);
    return index == -1 ? null : _fields[index];
  }

  @override
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
  }) async {
    final field = SportsField(
      id: FieldId(_nextId++),
      ownerId: ownerId,
      name: name,
      description: description,
      sport: sport,
      address: address,
      city: city,
      pricePerHour: pricePerHour,
      contactPhone: contactPhone,
      imageUrls: imageUrls,
      confirmationMode: confirmationMode,
      // Nov teren uvek čeka odobrenje administratora.
      approvalStatus: ApprovalStatus.pending,
    );
    _fields.add(field);
    return field;
  }

  @override
  Future<SportsField> updateField(SportsField field) async {
    final index = _indexOf(field.id);
    if (index == -1) throw EntityNotFound('field', field.id.value);

    final current = _fields[index];
    // Menjaju se podaci terena; vlasnik se ne menja, a odobrenost određuje pravilo.
    final updated = current.copyWith(
      name: field.name,
      description: field.description,
      sport: field.sport,
      address: field.address,
      city: field.city,
      pricePerHour: field.pricePerHour,
      contactPhone: field.contactPhone,
      imageUrls: field.imageUrls,
      confirmationMode: field.confirmationMode,
      isActive: field.isActive,
      approvalStatus: approvalStatusAfterOwnerEdit(current.approvalStatus),
    );
    return _fields[index] = updated;
  }

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async => [
    for (final field in _fields)
      if (field.approvalStatus == ApprovalStatus.pending) field,
  ];

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async {
    final index = _indexOf(fieldId);
    if (index == -1) throw EntityNotFound('field', fieldId.value);

    final current = _fields[index];
    if (decision == ApprovalStatus.pending ||
        !canTransitionApprovalStatus(current.approvalStatus, decision)) {
      throw ApprovalTransitionNotAllowed(current.approvalStatus, decision);
    }

    // Razlog se čuva samo uz odbijanje; odobravanje ga briše.
    final reviewed = SportsField(
      id: current.id,
      ownerId: current.ownerId,
      name: current.name,
      description: current.description,
      sport: current.sport,
      address: current.address,
      city: current.city,
      pricePerHour: current.pricePerHour,
      contactPhone: current.contactPhone,
      imageUrls: current.imageUrls,
      confirmationMode: current.confirmationMode,
      isActive: current.isActive,
      approvalStatus: decision,
      rejectionReason: decision == ApprovalStatus.rejected ? reason : null,
    );
    return _fields[index] = reviewed;
  }

  int _indexOf(FieldId id) => _fields.indexWhere((field) => field.id == id);
}
