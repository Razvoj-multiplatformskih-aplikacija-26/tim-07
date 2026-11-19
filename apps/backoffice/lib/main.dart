import 'package:api_client/api_client.dart';
import 'package:flutter/material.dart';
import 'package:session_storage/session_storage.dart';

import 'app.dart';
import 'server_address.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(baseUri: serverAddress(), session: createSessionStore());
  runApp(
    BackofficeApp(
      repository: HttpReservationRepository(api),
      fieldRepository: HttpFieldRepository(api),
      scheduleRepository: HttpScheduleRepository(api),
      authRepository: HttpSessionRepository(api),
      statisticsRepository: HttpStatisticsRepository(api),
      userRepository: HttpUserRepository(api),
    ),
  );
}
