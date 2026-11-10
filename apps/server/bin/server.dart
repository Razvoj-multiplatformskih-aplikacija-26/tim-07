import 'dart:io';

import 'package:server/server.dart';

/// Ulazna tačka: `dart run` u `apps/server` ili `/app/server` u Docker-u.
Future<void> main() async {
  final ServerConfig config;
  try {
    config = await ServerConfig.load();
  } on ConfigException catch (error) {
    stderr.writeln(error);
    stderr.writeln('Kopiraj .env.example u .env (cp .env.example .env).');
    exitCode = 78; // EX_CONFIG
    return;
  }

  // Server čeka bazu (Docker je podiže sporije) umesto da odmah padne.
  final database = await Database.connect(
    host: config.dbHost,
    port: config.dbPort,
    user: config.dbUser,
    password: config.dbPassword,
    database: config.dbName,
    log: stdout.writeln,
  );
  stdout.writeln('Povezan sa bazom ${config.dbHost}:${config.dbPort}/${config.dbName}');

  // Šema se pravi samo iz fajlova u repozitorijumu (T35).
  try {
    final migrations = await Migration.readDirectory(Directory(config.migrationsDirectory));
    await MigrationRunner(database, log: stdout.writeln).migrate(migrations);
  } on Object catch (error) {
    stderr.writeln(error);
    await database.close();
    exitCode = 1;
    return;
  }

  final handler = buildHandler(
    modules: [HealthRoutes(isDatabaseReady: database.ping)],
    corsAllowedOrigins: config.corsAllowedOrigins,
  );

  final server = await startServer(
    handler,
    host: config.host,
    port: config.port,
  );

  stdout.writeln('Terenzo server sluša na http://${config.host}:${server.port}');

  // Uredno gašenje na Ctrl+C i `docker stop`. Windows ne podržava SIGTERM.
  final signals = [
    ProcessSignal.sigint,
    if (!Platform.isWindows) ProcessSignal.sigterm,
  ];
  for (final signal in signals) {
    signal.watch().listen((_) async {
      stdout.writeln('Gašenje servera…');
      await server.close();
      await database.close();
      exit(0);
    });
  }
}
