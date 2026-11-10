import 'dart:io';

import 'package:server/server.dart';

Future<void> main() async {
  final ServerConfig config;
  try {
    config = await ServerConfig.load();
  } on ConfigException catch (error) {
    stderr.writeln(error);
    stderr.writeln('Kopiraj .env.example u .env (cp .env.example .env).');
    exitCode = 78;
    return;
  }

  final database = await Database.connect(
    host: config.dbHost,
    port: config.dbPort,
    user: config.dbUser,
    password: config.dbPassword,
    database: config.dbName,
    log: stdout.writeln,
  );
  stdout.writeln('Povezan sa bazom ${config.dbHost}:${config.dbPort}/${config.dbName}');

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
    modules: [
      HealthRoutes(isDatabaseReady: database.ping),
      AuthRoutes(
        credentials: MySqlCredentialStore(database),
        users: MySqlUserRepository(database),
        tokens: TokenService(secret: config.jwtSecret, ttl: config.tokenTtl),
      ),
    ],
    corsAllowedOrigins: config.corsAllowedOrigins,
  );

  final server = await startServer(
    handler,
    host: config.host,
    port: config.port,
  );

  stdout.writeln('Terenzo server sluša na http://${config.host}:${server.port}');

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
