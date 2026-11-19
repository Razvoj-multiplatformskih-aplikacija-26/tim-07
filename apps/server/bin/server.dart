import 'dart:async';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart' show IOAdapter, RelicServer;
import 'package:server/server.dart';

Future<void> main() async {
  final config = ServerConfig.fromEnvironment(serverEnvironment());
  final database = Pool<void>.withUrl(config.databaseUrl);
  await seedDemoData(database, now: DateTime.now(), demoPassword: config.demoPassword);
  final terenzo = PostgresTerenzo(database);
  final handlers = TerenzoHandlers(
    terenzo: terenzo,
    notifications: FakeNotificationGateway(apiKey: config.notificationApiKey),
  );
  final sessions = SessionHandlers(store: TerenzoStore(database), secret: config.jwtSecret, ttl: config.sessionTtl);
  final server = RelicServer(() => IOAdapter.bind(InternetAddress(config.host), port: config.port));
  await server.mountAndStart(buildHandler(handlers, sessions, corsOrigins: config.corsOrigins));
  stdout.writeln('Terenzo server on http://${config.host}:${config.port}');
  await _stopSignal();
  await server.close();
  await database.close();
}

Future<void> _stopSignal() async {
  final stop = Completer<void>();
  final subscriptions = [
    for (final signal in [ProcessSignal.sigint, if (!Platform.isWindows) ProcessSignal.sigterm])
      signal.watch().listen((_) => stop.isCompleted ? null : stop.complete()),
  ];
  await stop.future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
}
