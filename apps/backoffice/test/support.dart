import 'package:backoffice/app.dart';
import 'package:backoffice/data/backoffice_demo_data.dart';
import 'package:backoffice/data/backoffice_fake_repository.dart';
import 'package:backoffice/data/backoffice_repository.dart';
import 'package:flutter/widgets.dart';

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
