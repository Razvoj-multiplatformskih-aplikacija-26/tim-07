import 'dart:io';

import 'package:relic/relic.dart';

import 'json.dart';

Middleware handleErrors() {
  return (Handler next) {
    return (Request request) async {
      try {
        return await next(request);
      } on HttpError catch (error) {
        return error.toResponse();
      } catch (error, stackTrace) {
        stderr.writeln(
          '[${DateTime.now().toUtc().toIso8601String()}] '
          '${request.method.name.toUpperCase()} ${request.url.path} -> 500\n'
          '$error\n$stackTrace',
        );
        return errorResponse(500, 'internal');
      }
    };
  };
}

Middleware cors(List<String> allowedOrigins) {
  bool isAllowed(String origin) {
    for (final allowed in allowedOrigins) {
      if (allowed == origin) return true;
      if (allowed.endsWith(':*')) {
        final prefix = allowed.substring(0, allowed.length - 1);
        final port = origin.startsWith(prefix)
            ? origin.substring(prefix.length)
            : null;
        if (port != null && int.tryParse(port) != null) return true;
      }
    }
    return false;
  }

  void addCorsHeaders(MutableHeaders headers, String origin) {
    headers['Access-Control-Allow-Origin'] = [origin];
    headers['Vary'] = ['Origin'];
    headers['Access-Control-Allow-Methods'] = [
      'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    ];
    headers['Access-Control-Allow-Headers'] = ['Authorization, Content-Type'];
    headers['Access-Control-Max-Age'] = ['600'];
  }

  return (Handler next) {
    return (Request request) async {
      final origin = request.headers['Origin']?.firstOrNull;
      final allowed = origin != null && isAllowed(origin);

      if (request.method == Method.options) {
        if (!allowed) {
          return Response.forbidden();
        }
        return Response.noContent(
          headers: Headers.build((h) => addCorsHeaders(h, origin)),
        );
      }

      final result = await next(request);
      if (!allowed || result is! Response) {
        return result;
      }

      return result.copyWith(
        headers: result.headers.transform((h) => addCorsHeaders(h, origin)),
      );
    };
  };
}
