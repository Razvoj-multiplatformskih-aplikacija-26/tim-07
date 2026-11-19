import 'package:contract/contract.dart';
import 'package:relic/relic.dart';

import 'cors.dart';
import 'handlers.dart';
import 'http.dart';
import 'sessions.dart';

Handler buildHandler(TerenzoHandlers handlers, SessionHandlers sessions, {required List<String> corsOrigins}) {
  final signedIn = sessions.signedIn;
  final optional = sessions.optionallySignedIn;
  final router = RelicRouter()
    ..get(ApiPaths.health, (request) => Response.ok(body: Body.fromString('ok')))
    ..post(ApiPaths.login, sessions.logIn)
    ..get(ApiPaths.me, signedIn(sessions.current))
    ..delete(ApiPaths.me, signedIn(sessions.logOut))
    ..get(ApiPaths.sports, handlers.sports)
    ..get(ApiPaths.fields, optional(handlers.fields))
    ..post(ApiPaths.fields, signedIn(handlers.createField))
    ..get(ApiPaths.fieldsAwaitingApproval, signedIn(handlers.fieldsAwaitingApproval))
    ..get('${ApiPaths.fields}/:id', optional(handlers.field))
    ..patch('${ApiPaths.fields}/:id', signedIn(handlers.updateField))
    ..get('${ApiPaths.fields}/:id/availability', optional(handlers.availability))
    ..get('${ApiPaths.fields}/:id/schedule', optional(handlers.schedule))
    ..put('${ApiPaths.fields}/:id/schedule', signedIn(handlers.replaceSchedule))
    ..get('${ApiPaths.fields}/:id/blocked-periods', optional(handlers.blockedPeriods))
    ..post('${ApiPaths.fields}/:id/blocked-periods', signedIn(handlers.addBlockedPeriod))
    ..post('${ApiPaths.fields}/:id/review', signedIn(handlers.reviewField))
    ..get(ApiPaths.reservations, signedIn(handlers.reservations))
    ..post(ApiPaths.reservations, signedIn(handlers.createReservation))
    ..get('${ApiPaths.reservations}/:id', signedIn(handlers.reservation))
    ..post('${ApiPaths.reservations}/:id/confirm', signedIn(handlers.confirm))
    ..post('${ApiPaths.reservations}/:id/reject', signedIn(handlers.reject))
    ..post('${ApiPaths.reservations}/:id/cancel', signedIn(handlers.cancel))
    ..post('${ApiPaths.reservations}/:id/check-in', signedIn(handlers.checkIn))
    ..get(ApiPaths.stats, signedIn(handlers.statistics))
    ..get(ApiPaths.users, signedIn(handlers.users))
    ..fallback = respondWith((request) => errorResponse(const ErrorDto(code: ErrorCodes.notFound)));
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(allowOrigins(corsOrigins))
      .addMiddleware(handleErrors())
      .addHandler(router.asHandler);
}
