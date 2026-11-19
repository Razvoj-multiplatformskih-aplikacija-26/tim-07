import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';

import 'mobile_demo_data.dart';

/// Tereni iz memorije sa kašnjenjem i simulacijom greške i praznog odgovora,
/// dok mobilna aplikacija nema server (T52). Zamenjuje se HTTP repozitorijumom
/// bez izmene Bloc-ova i ekrana.
class MobileFakeFieldRepository implements SportsFieldRepository {
  final SportsFieldRepository _store;
  final Duration delay;

  bool _failNext = false;
  bool _emptyNext = false;

  MobileFakeFieldRepository(
    this._store, {
    this.delay = const Duration(milliseconds: 600),
  });

  /// Sledeći zahtev puca kao da server ne radi.
  void failNextRequest() => _failNext = true;

  /// Sledeće učitavanje kataloga vraća praznu listu.
  void returnEmptyOnNextRequest() => _emptyNext = true;

  Future<void> _simulateNetwork() async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    if (_failNext) {
      _failNext = false;
      throw const ServerUnreachableException();
    }
  }

  @override
  Future<List<SportsField>> getPublicFields() async {
    await _simulateNetwork();

    if (_emptyNext) {
      _emptyNext = false;
      return const [];
    }

    return _store.getPublicFields();
  }

  @override
  Future<SportsField?> getFieldById(FieldId id) async {
    await _simulateNetwork();
    return _store.getFieldById(id);
  }

  @override
  Future<List<SportsField>> getFields() async {
    await _simulateNetwork();
    return _store.getFields();
  }

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async {
    await _simulateNetwork();
    return _store.getFieldsByOwner(ownerId);
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
    await _simulateNetwork();
    return _store.createField(
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
    );
  }

  @override
  Future<SportsField> updateField(SportsField field) async {
    await _simulateNetwork();
    return _store.updateField(field);
  }

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async {
    await _simulateNetwork();
    return _store.getFieldsAwaitingApproval();
  }

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async {
    await _simulateNetwork();
    return _store.reviewField(
      fieldId: fieldId,
      reviewerId: reviewerId,
      decision: decision,
      reason: reason,
    );
  }
}

MobileFakeFieldRepository createMobileFieldRepository({
  Duration delay = const Duration(milliseconds: 600),
}) {
  return MobileFakeFieldRepository(
    FakeSportsFieldRepository(fields: MobileDemoData.fields),
    delay: delay,
  );
}
