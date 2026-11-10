import 'dart:convert';

import 'package:relic/relic.dart';

/// Odgovor sa JSON telom i zadatim HTTP statusom.
Response jsonResponse(int statusCode, Object? data) {
  return Response(
    statusCode,
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}

/// Greška u obliku iz `docs/kt2-decisions.md` (odluka 13):
/// `{"error": {"code": "...", "details": {...}}}`.
///
/// Server nikad ne šalje poruku za korisnika, samo kod i podatke.
Response errorResponse(
  int statusCode,
  String code, {
  Map<String, Object?> details = const {},
}) {
  return jsonResponse(statusCode, {
    'error': {'code': code, 'details': details},
  });
}

/// Zahtev ne može da se obradi zbog neispravnog ulaza.
///
/// Rute bacaju ovu grešku, a [handleErrors] je pretvara u odgovor.
final class HttpError implements Exception {
  final int statusCode;
  final String code;
  final Map<String, Object?> details;

  const HttpError(this.statusCode, this.code, [this.details = const {}]);

  const HttpError.badRequest([Map<String, Object?> details = const {}])
      : this(400, 'bad_request', details);

  const HttpError.notFound() : this(404, 'not_found');

  const HttpError.unauthenticated() : this(401, 'unauthenticated');

  const HttpError.forbidden() : this(403, 'forbidden');

  Response toResponse() => errorResponse(statusCode, code, details: details);

  @override
  String toString() => 'HttpError($statusCode, $code, $details)';
}

/// Čita telo zahteva kao JSON objekat.
///
/// Prazno telo, neispravan JSON ili nešto što nije objekat daju `400`.
Future<Map<String, Object?>> readJsonObject(Request request) async {
  final String text;
  try {
    text = await request.readAsString(maxLength: 64 * 1024);
  } on MaxBodySizeExceeded {
    throw const HttpError(413, 'payload_too_large');
  }

  if (text.trim().isEmpty) {
    throw const HttpError.badRequest({'reason': 'empty_body'});
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const HttpError.badRequest({'reason': 'invalid_json'});
  }

  if (decoded is! Map<String, Object?>) {
    throw const HttpError.badRequest({'reason': 'expected_object'});
  }

  return decoded;
}
