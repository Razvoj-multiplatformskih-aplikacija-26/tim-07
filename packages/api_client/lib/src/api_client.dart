import 'dart:async';
import 'dart:convert';

import 'package:contract/contract.dart';
import 'package:http/http.dart' as http;
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';

import 'session_store.dart';

/// Jedini deo koji priča HTTP sa serverom. Isti kod radi na VM-u (telefon,
/// desktop) i u pregledaču: koristi samo `package:http`, bez `dart:io`.
///
/// Sve što pođe naopako stiže kao jedan od dva izuzetka iz paketa `messages`,
/// pa Bloc i ekran ne znaju ništa o HTTP-u:
/// - [ServerUnreachableException]: nema mreže, server ne radi ili ne odgovara na vreme;
/// - [ServerRejectedException]: server je odgovorio greškom (kod i podaci pravila).
///
/// Token ide u `Authorization` zaglavlju, ne u kolačiću (odluka 10), pa
/// pregledač ne treba posebnu varijantu klijenta.
final class ApiClient {
  ApiClient({
    required this.baseUri,
    SessionStore? session,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : session = session ?? MemorySessionStore(),
       _http = httpClient ?? http.Client();

  /// Adresa servera, npr. `http://10.0.2.2:8080` (emulator) ili `http://localhost:8080`.
  final Uri baseUri;
  final SessionStore session;
  final Duration timeout;
  final http.Client _http;
  final _expirations = StreamController<void>.broadcast();

  /// Javlja kada server kaže da prijava ne važi (`token_expired`, `invalid_token`).
  /// Token je tada već obrisan; aplikacija vraća korisnika na prijavu.
  Stream<void> get expirations => _expirations.stream;

  Future<Object?> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<Object?> post(String path, {Map<String, Object?>? body}) =>
      _send('POST', path, body: body);

  Future<Object?> put(String path, {Map<String, Object?>? body}) =>
      _send('PUT', path, body: body);

  Future<Object?> patch(String path, {Map<String, Object?>? body}) =>
      _send('PATCH', path, body: body);

  Future<Object?> delete(String path) => _send('DELETE', path);

  void close() {
    _http.close();
    _expirations.close();
  }

  Uri _uri(String path, Map<String, String>? query) {
    final prefix = baseUri.path.replaceAll(RegExp(r'/+$'), '');
    return baseUri.replace(
      path: '$prefix$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers['Accept'] = 'application/json';

    final token = await session.read();
    if (token != null) {
      request.headers[ApiHeaders.authorization] = ApiHeaders.bearer(token);
    }
    if (body != null) {
      request
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _http
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on http.ClientException {
      throw const ServerUnreachableException();
    } on TimeoutException {
      throw const ServerUnreachableException();
    }

    return _answer(response, sentToken: token != null);
  }

  Future<Object?> _answer(
    http.Response response, {
    required bool sentToken,
  }) async {
    final status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        // Server je rekao "u redu", ali telo nije JSON (npr. proxy).
        throw const ServerRejectedException(
          ErrorDto(code: ErrorCodes.internal),
        );
      }
    }

    final error = _errorOf(response);
    if (sentToken &&
        (error.code == ErrorCodes.tokenExpired ||
            error.code == ErrorCodes.invalidToken ||
            // Administrator je deaktivirao nalog dok je prijava važila.
            error.code == ErrorCodes.accountDeactivated)) {
      await session.clear();
      if (!_expirations.isClosed) _expirations.add(null);
    }
    throw ServerRejectedException(error);
  }

  /// Greška iz tela odgovora. Telo koje nije greška servera (HTML sa proxy-ja,
  /// prazan odgovor) postaje opšta greška prema statusu, bez tehničkog teksta.
  ErrorDto _errorOf(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, Object?>) return ErrorDto.fromJson(json);
    } on FormatException {
      // pada na opštu grešku ispod
    }
    return ErrorDto(
      code: switch (response.statusCode) {
        401 => ErrorCodes.unauthenticated,
        403 => ErrorCodes.forbidden,
        404 => ErrorCodes.notFound,
        413 => ErrorCodes.payloadTooLarge,
        >= 400 && < 500 => ErrorCodes.badRequest,
        _ => ErrorCodes.internal,
      },
    );
  }
}

/// Čita odgovor servera u domen. Odgovor koji ne može da se pročita ili sadrži
/// kod koji ova verzija ne poznaje je greška servera za korisnika, ne pad.
T readBody<T>(Object? json, T Function(Map<String, Object?> json) read) {
  try {
    return read(objectOf(json));
  } on FormatException {
    throw const ServerRejectedException(ErrorDto(code: ErrorCodes.internal));
  } on UnknownCodeException {
    throw const ServerRejectedException(ErrorDto(code: ErrorCodes.internal));
  }
}

Map<String, Object?> objectOf(Object? json) => switch (json) {
  final Map<String, Object?> object => object,
  _ => throw FormatException('Expected a JSON object', json),
};

/// Da li je [error] odgovor „ne postoji“ (za `getById` koji vraća `null`).
bool isNotFound(Object error) =>
    error is ServerRejectedException && error.error.code == ErrorCodes.notFound;
