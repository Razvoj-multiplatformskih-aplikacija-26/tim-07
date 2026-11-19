import 'package:flutter/material.dart';

import 'app.dart';
import 'data/backoffice_demo_data.dart';
import 'data/backoffice_repository.dart';

void main() {
  final reservations = createBackofficeRepository();

  runApp(
    BackofficeApp(
      repository: reservations,
      fieldRepository: createBackofficeFieldRepository(),
      scheduleRepository: createBackofficeScheduleRepository(
        reservations: reservations,
      ),
      owner: BackofficeDemoData.owner,
    ),
  );
}
