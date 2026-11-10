import 'dart:async';
import 'dart:io';

import 'package:relic/relic.dart';

import 'json.dart';
import 'middleware.dart';

/// Grupa ruta koja se kači na ruter (zdravlje, prijava, rezervacije…).
///
/// Svaka grupa dobija svoje zavisnosti kroz konstruktor, pa se u testu
/// može podići server sa lažnim repozitorijumima.
abstract interface class RouteModule {
  void register(RelicRouter router);
}

/// `GET /health` za Docker i za proveru da server radi.
///
/// [isDatabaseReady] je opcion: kad postoji, `/health` vraća `503` dok
/// baza ne odgovara.
final class HealthRoutes implements RouteModule {
  final Future<bool> Function()? isDatabaseReady;

  const HealthRoutes({this.isDatabaseReady});

  @override
  void register(RelicRouter router) {
    router.get('/health', (Request request) async {
      final check = isDatabaseReady;
      if (check != null && !await check()) {
        return jsonResponse(503, {'status': 'starting', 'database': 'down'});
      }
      return jsonResponse(200, {
        'status': 'ok',
        if (check != null) 'database': 'up',
      });
    });
  }
}

/// Sklapa ceo HTTP handler: middleware + rute + 404 za nepoznatu adresu.
Handler buildHandler({
  required List<RouteModule> modules,
  List<String> corsAllowedOrigins = const [],
  bool logRequestsToStdout = true,
}) {
  final router = RelicRouter()
    ..fallback = (Request request) => errorResponse(404, 'not_found');

  for (final module in modules) {
    module.register(router);
  }

  var pipeline = const Pipeline();
  if (logRequestsToStdout) {
    pipeline = pipeline.addMiddleware(logRequests());
  }

  return pipeline
      .addMiddleware(cors(corsAllowedOrigins))
      .addMiddleware(handleErrors())
      .addHandler(router.asHandler);
}

/// Podiže HTTP server nad [handler].
///
/// Port `0` bira slobodan port (koristi se u testovima), a pravi port se
/// čita iz [RelicServer.port].
Future<RelicServer> startServer(
  Handler handler, {
  required String host,
  required int port,
}) async {
  final server = RelicServer(
    () => IOAdapter.bind(InternetAddress(host), port: port),
  );
  await server.mountAndStart(handler);
  return server;
}
