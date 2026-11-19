import 'dart:convert';
import 'dart:io';

import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:relic/relic.dart';

Response json(int status, Object? body) =>
    Response(status, body: Body.fromString(jsonEncode(body), mimeType: MimeType.json));

Response errorResponse(ErrorDto error) => json(httpStatusFor(error.code), error.toJson());

Response problem(Object error) => errorResponse(errorOf(error) ?? const ErrorDto(code: ErrorCodes.internal));

ErrorDto? errorOf(Object error) => switch (error) {
  Refused(:final error) => error,
  ScheduleRuleViolation(:final error) => ErrorDto(
    code: ErrorCodes.badRequest,
    details: {
      ErrorDetailKeys.reason: switch (error) {
        OpeningAfterClosing() => 'opening_after_closing',
        InvalidTimeOfDay() => 'invalid_time_of_day',
        DuplicateScheduleDay() => 'duplicate_day',
        ScheduleForOtherField() => 'other_field',
      },
      if (error.day case final day?) 'day': weekDayToCode(day),
    },
  ),
  _ => failureOf(error)?.error,
};

final class Refused implements Exception {
  const Refused(this.error);

  const Refused.forbidden() : error = const ErrorDto(code: ErrorCodes.forbidden);

  const Refused.notFound() : error = const ErrorDto(code: ErrorCodes.notFound);

  Refused.badRequest(String reason)
    : error = ErrorDto(code: ErrorCodes.badRequest, details: {ErrorDetailKeys.reason: reason});

  final ErrorDto error;

  @override
  String toString() => 'Refused(${error.code})';
}

const maxBodyBytes = 64 * 1024;

Future<Map<String, Object?>> readObject(Request request) async {
  final String text;
  try {
    text = await request.readAsString(maxLength: maxBodyBytes);
  } on MaxBodySizeExceeded {
    throw const Refused(ErrorDto(code: ErrorCodes.payloadTooLarge));
  }
  if (text.trim().isEmpty) return const {};
  return switch (jsonDecode(text)) {
    final Map<String, Object?> object => object,
    _ => throw const FormatException('Expected a JSON object'),
  };
}

T parseBody<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException catch (error) {
    throw Refused.badRequest(error.message);
  } on ArgumentError catch (error) {
    throw Refused.badRequest('${error.message}');
  } on TypeError {
    throw Refused.badRequest('invalid_body');
  } on UnknownCodeException catch (error) {
    throw Refused.badRequest(error.toString());
  }
}

Middleware handleErrors() =>
    (Handler next) => (Request request) async {
      try {
        return await next(request);
      } on FormatException catch (error) {
        return errorResponse(ErrorDto(code: ErrorCodes.badRequest, details: {ErrorDetailKeys.reason: error.message}));
      } catch (error, stackTrace) {
        final known = errorOf(error);
        if (known != null) return errorResponse(known);
        stderr.writeln('${request.method} ${request.url.path}: $error\n$stackTrace');
        return errorResponse(const ErrorDto(code: ErrorCodes.internal));
      }
    };
