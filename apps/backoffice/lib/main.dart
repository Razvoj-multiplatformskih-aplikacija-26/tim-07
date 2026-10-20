import 'package:flutter/material.dart';

import 'app.dart';
import 'data/backoffice_repository.dart';

void main() {
  runApp(BackofficeApp(repository: createBackofficeRepository()));
}
