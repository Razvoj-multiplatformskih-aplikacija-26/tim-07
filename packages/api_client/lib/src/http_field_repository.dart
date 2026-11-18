import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';

import 'api_client.dart';
import 'page.dart';
import 'paging.dart';

/// Tereni preko HTTP-a. Javni katalog radi i bez prijave (odluka 8); šta
/// prijavljeni vlasnik i administrator vide povrh toga određuje server.
final class HttpFieldRepository implements SportsFieldRepository {
  const HttpFieldRepository(this._api);

  final ApiClient _api;

  /// Svi tereni koje pozivalac sme da vidi (administrator: svi).
  @override
  Future<List<SportsField>> getFields() async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.fields,
      fromJson: FieldDto.fromJson,
    );
    return dtos.toDomainKnown();
  }

  /// Aktivni i odobreni tereni. Server za prijavljenog vlasnika vraća i njegove
  /// neodobrene, pa se ovde dodatno suzi istim pravilom iz domena.
  @override
  Future<List<SportsField>> getPublicFields() async {
    final fields = await getFields();
    return [
      for (final field in fields)
        if (isFieldPublic(field)) field,
    ];
  }

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async {
    final fields = await getFields();
    return [
      for (final field in fields)
        if (field.ownerId == ownerId) field,
    ];
  }

  /// Jedna strana javnog kataloga sa filterima, za pretragu u aplikaciji.
  Future<Page<SportsField>> getFieldsPage({
    SportType? sport,
    String? city,
    String? search,
    int limit = ApiPaging.defaultLimit,
    int offset = 0,
  }) async {
    final page = await getPageDto(
      _api,
      ApiPaths.fields,
      query: {
        if (sport != null) ApiQuery.sport: sportToCode(sport),
        if (city != null && city.isNotEmpty) ApiQuery.city: city,
        if (search != null && search.isNotEmpty) ApiQuery.search: search,
      },
      limit: limit,
      offset: offset,
      fromJson: FieldDto.fromJson,
    );
    return Page(
      items: page.items.toDomainKnown(),
      total: page.total,
      limit: page.limit,
      offset: page.offset,
    );
  }

  /// Sportovi koji postoje na aktivnim, odobrenim terenima: brzi filter u
  /// aplikaciji se pravi iz ovoga, a ne iz hardkodovane liste. Sport koji ova
  /// verzija ne poznaje se preskače.
  Future<List<SportType>> getAvailableSports() async {
    final json = await _api.get(ApiPaths.sports);
    return readBody(json, SportsDto.fromJson).toDomainKnown();
  }

  @override
  Future<SportsField?> getFieldById(FieldId id) async {
    try {
      final json = await _api.get(ApiPaths.field(id.value));
      final field = readBody(json, (o) => FieldDto.fromJson(o).toDomain());
      return field;
    } on ServerRejectedException catch (error) {
      if (isNotFound(error)) return null;
      rethrow;
    }
  }

  /// Vlasnik i odobrenost se ne šalju: vlasnik je pozivalac iz tokena, a nov
  /// teren uvek čeka odobrenje administratora.
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
    final request = SaveFieldRequestDto(
      name: name,
      description: description,
      sport: sportToCode(sport),
      address: address,
      city: city,
      pricePerHour: pricePerHour,
      contactPhone: contactPhone,
      imageUrls: imageUrls,
      confirmationMode: confirmationModeToCode(confirmationMode),
    );
    final json = await _api.post(ApiPaths.fields, body: request.toJson());
    return readBody(json, (o) => FieldDto.fromJson(o).toDomain());
  }

  @override
  Future<SportsField> updateField(SportsField field) async {
    final json = await _api.patch(
      ApiPaths.field(field.id.value),
      body: field.toSaveRequest().toJson(),
    );
    return readBody(json, (o) => FieldDto.fromJson(o).toDomain());
  }

  /// Samo administrator.
  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async {
    final dtos = await getAllDtos(
      _api,
      ApiPaths.fieldsAwaitingApproval,
      fromJson: FieldDto.fromJson,
    );
    return dtos.toDomainKnown();
  }

  /// `reviewerId` se ne šalje: administrator je pozivalac iz tokena.
  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async {
    final request = FieldReviewRequestDto(
      decision: approvalStatusToCode(decision),
      reason: reason,
    );
    final json = await _api.post(
      ApiPaths.fieldReview(fieldId.value),
      body: request.toJson(),
    );
    return readBody(json, (o) => FieldDto.fromJson(o).toDomain());
  }
}
