import 'dart:async';
import 'dart:io';

import 'package:relic/relic.dart';

import 'json.dart';
import 'middleware.dart';

abstract interface class RouteModule {
  void register(RelicRouter router);
}

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
