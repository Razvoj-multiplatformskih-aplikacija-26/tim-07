import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:messages/messages.dart';

/// Backoffice nad lažnim izvorima, kao vlasnik demo terena.
Widget backofficeApp(BackofficeFakeReservationRepository repository) {
  return BackofficeApp(
    repository: repository,
    fieldRepository: createBackofficeFieldRepository(),
    scheduleRepository: createBackofficeScheduleRepository(
      reservations: repository,
    ),
    owner: BackofficeDemoData.owner,
  );
}

/// Spisak terena koji ne može da se učita.
final class FailingFields implements SportsFieldRepository {
  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getFields() async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getPublicFields() async =>
      throw const ServerUnreachableException();

  @override
  Future<SportsField?> getFieldById(FieldId id) async =>
      throw const ServerUnreachableException();

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
  }) async => throw const ServerUnreachableException();

  @override
  Future<SportsField> updateField(SportsField field) async =>
      throw const ServerUnreachableException();

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async =>
      throw const ServerUnreachableException();

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async => throw const ServerUnreachableException();
}
