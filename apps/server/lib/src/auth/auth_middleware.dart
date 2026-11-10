import 'package:relic/relic.dart';

import '../http/json.dart';
import 'tokens.dart';

final currentSession = ContextProperty<AuthSession>('session');

Handler requireAuth(TokenService tokens, Handler handler) {
  return (Request request) async {
    final token = bearerToken(request);
    if (token == null) return unauthorized('unauthenticated');

    try {
      currentSession[request] = tokens.verify(token);
    } on TokenRejected catch (rejected) {
      return unauthorized(rejected.code);
    }
    return handler(request);
  };
}

Handler optionalAuth(TokenService tokens, Handler handler) {
  return (Request request) async {
    final token = bearerToken(request);
    if (token != null) {
      try {
        currentSession[request] = tokens.verify(token);
      } on TokenRejected catch (rejected) {
        return unauthorized(rejected.code);
      }
    }
    return handler(request);
  };
}

String? bearerToken(Request request) {
  final header = request.headers['Authorization']?.firstOrNull;
  if (header == null) return null;
  const prefix = 'Bearer ';
  if (header.length <= prefix.length ||
      header.substring(0, prefix.length).toLowerCase() != prefix.toLowerCase()) {
    return null;
  }
  return header.substring(prefix.length).trim();
}

Response unauthorized(String code) {
  final response = errorResponse(401, code);
  return response.copyWith(
    headers: response.headers.transform((h) => h['WWW-Authenticate'] = ['Bearer']),
  );
}
