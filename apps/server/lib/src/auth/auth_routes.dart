import 'package:domain/domain.dart';
import 'package:relic/relic.dart';

import '../http/app.dart';
import '../http/json.dart';
import 'auth_middleware.dart';
import 'credential_store.dart';
import 'passwords.dart';
import 'tokens.dart';

final class AuthRoutes implements RouteModule {
  final CredentialStore credentials;
  final UserRepository users;
  final TokenService tokens;

  final Future<String> _noAccountHash = hashPassword('nepostojeci nalog');

  AuthRoutes({required this.credentials, required this.users, required this.tokens});

  @override
  void register(RelicRouter router) {
    router.post('/auth/login', _login);
    router.get('/auth/me', requireAuth(tokens, _me));
  }

  Future<Response> _login(Request request) async {
    final body = await readJsonObject(request);
    final email = body['email'];
    final password = body['password'];
    if (email is! String || email.trim().isEmpty || password is! String || password.isEmpty) {
      throw const HttpError.badRequest({'fields': ['email', 'password']});
    }

    final account = await credentials.findByEmail(email);
    final matches = await verifyPassword(password, account?.passwordHash ?? await _noAccountHash);
    if (account == null || !matches) return unauthorized('invalid_credentials');

    final issued = tokens.issue(account.user);
    return jsonResponse(200, {
      'token': issued.token,
      'expiresAt': issued.expiresAt.toIso8601String(),
      'user': userJson(account.user),
    });
  }

  Future<Response> _me(Request request) async {
    final session = currentSession.get(request);
    final user = await users.getUserById(session.userId);
    if (user == null) return unauthorized('invalid_token');
    return jsonResponse(200, {
      'expiresAt': session.expiresAt.toIso8601String(),
      'user': userJson(user),
    });
  }
}

Map<String, Object?> userJson(AppUser user) => {
      'id': user.id.value,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'email': user.email,
      'role': user.role.name,
    };
