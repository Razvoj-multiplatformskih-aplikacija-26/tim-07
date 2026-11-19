import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:relic/relic.dart';

import 'http.dart';
import 'notifications.dart';
import 'postgres_terenzo.dart';
import 'sessions.dart';

final class TerenzoHandlers {
  TerenzoHandlers({required this.terenzo, required this.notifications});

  final PostgresTerenzo terenzo;
  final NotificationGateway notifications;

  Future<Response> fields(Request request) async {
    final actor = optionalActorOf(request);
    final sport = _optionalQuery(request, ApiQuery.sport);
    final city = _optionalQuery(request, ApiQuery.city)?.toLowerCase();
    final search = _optionalQuery(request, ApiQuery.search)?.toLowerCase();
    final sportFilter = sport == null ? null : parseBody(() => requireKnown(sportFromCode(sport), 'sport', sport));
    final visible = [
      for (final field in await terenzo.getFields())
        if (canViewField(actor, field) &&
            (sportFilter == null || field.sport == sportFilter) &&
            (city == null || field.city.toLowerCase() == city) &&
            (search == null ||
                field.name.toLowerCase().contains(search) ||
                field.description.toLowerCase().contains(search)))
          field,
    ];
    return _page(request, visible, (field) => field.toDto().toJson());
  }

  Future<Response> field(Request request) async {
    final field = await _visibleField(request, optionalActorOf(request));
    return json(200, field.toDto().toJson());
  }

  Future<Response> sports(Request request) async => json(200, (await terenzo.publicSports()).toDto().toJson());

  Future<Response> createField(Request request) async {
    final actor = actorOf(request);
    if (!canCreateField(actor)) throw const Refused.forbidden();
    final object = await readObject(request);
    final body = parseBody(() => SaveFieldRequestDto.fromJson(object));
    final sport = parseBody(body.toSport);
    final mode = parseBody(body.toConfirmationMode);
    _requireFieldValues(body);
    final created = await terenzo.createField(
      ownerId: actor.id,
      name: body.name.trim(),
      description: body.description.trim(),
      sport: sport,
      address: body.address.trim(),
      city: body.city.trim(),
      pricePerHour: body.pricePerHour,
      contactPhone: body.contactPhone.trim(),
      imageUrls: body.imageUrls,
      confirmationMode: mode,
    );
    return json(201, created.toDto().toJson());
  }

  Future<Response> updateField(Request request) async {
    final actor = actorOf(request);
    final field = await _visibleField(request, actor);
    if (!canManageField(actor, field)) throw const Refused.forbidden();
    final object = await readObject(request);
    final body = parseBody(() => SaveFieldRequestDto.fromJson(object));
    _requireFieldValues(body);
    final updated = await terenzo.updateField(parseBody(() => body.applyTo(field)));
    return json(200, updated.toDto().toJson());
  }

  Future<Response> schedule(Request request) async {
    final field = await _visibleField(request, optionalActorOf(request));
    return json(200, (await terenzo.getSchedules(field.id)).toDto().toJson());
  }

  Future<Response> replaceSchedule(Request request) async {
    final actor = actorOf(request);
    final field = await _visibleField(request, actor);
    if (!canManageField(actor, field)) throw const Refused.forbidden();
    final object = await readObject(request);
    final schedules = parseBody(() => ScheduleDto.fromJson(object).toDomain(field.id));
    await terenzo.replaceSchedules(field.id, schedules);
    return json(200, (await terenzo.getSchedules(field.id)).toDto().toJson());
  }

  Future<Response> blockedPeriods(Request request) async {
    final field = await _visibleField(request, optionalActorOf(request));
    final from = _optionalInstant(request, ApiQuery.from);
    final to = _optionalInstant(request, ApiQuery.to);
    final periods = await terenzo.getBlockedPeriods(field.id, from: from, to: to);
    return _page(request, periods, (period) => period.toDto().toJson());
  }

  Future<Response> addBlockedPeriod(Request request) async {
    final actor = actorOf(request);
    final field = await _visibleField(request, actor);
    if (!canManageField(actor, field)) throw const Refused.forbidden();
    final object = await readObject(request);
    final period = parseBody(() => CreateBlockedPeriodRequestDto.fromJson(object).toDomain(field.id));
    final added = await terenzo.addBlockedPeriod(period);
    return json(201, added.toDto().toJson());
  }

  Future<Response> availability(Request request) async {
    final field = await _visibleField(request, optionalActorOf(request));
    final day = parseBody(() => _localDay(_query(request, ApiQuery.date)));
    final slots = await terenzo.getAvailability(fieldId: field.id, date: day);
    return json(200, slots.toDto(fieldId: field.id, date: day).toJson());
  }

  Future<Response> removeBlockedPeriod(Request request) async {
    final actor = actorOf(request);
    final field = await _visibleField(request, actor);
    if (!canManageField(actor, field)) throw const Refused.forbidden();
    final id = parseBody(() => int.parse(request.rawPathParameters[#blockId]!));
    await terenzo.removeBlockedPeriod(field.id, BlockedPeriodId(id));
    return Response.noContent();
  }

  Future<Response> fieldsAwaitingApproval(Request request) async {
    if (!canReviewField(actorOf(request))) throw const Refused.forbidden();
    return _page(request, await terenzo.getFieldsAwaitingApproval(), (field) => field.toDto().toJson());
  }

  Future<Response> reviewField(Request request) async {
    final actor = actorOf(request);
    final field = await _visibleField(request, actor);
    if (!canReviewField(actor)) throw const Refused.forbidden();
    final object = await readObject(request);
    final body = parseBody(() => FieldReviewRequestDto.fromJson(object));
    final decision = parseBody(() => requireKnown(approvalStatusFromCode(body.decision), 'approval', body.decision));
    final reviewed = await terenzo.reviewField(
      fieldId: field.id,
      reviewerId: actor.id,
      decision: decision,
      reason: body.reason,
    );
    return json(200, reviewed.toDto().toJson());
  }

  Future<Response> reservations(Request request) async {
    final actor = actorOf(request);
    final fieldId = _optionalQuery(request, ApiQuery.fieldId);
    final status = _optionalQuery(request, ApiQuery.status);
    final fieldFilter = fieldId == null ? null : FieldId(parseBody(() => int.parse(fieldId)));
    final statusFilter =
        status == null ? null : parseBody(() => requireKnown(reservationStatusFromCode(status), 'status', status));
    final fields = {for (final field in await terenzo.getFields()) field.id: field};
    final visible = [
      for (final reservation in await terenzo.getReservations())
        if (fields[reservation.fieldId] case final field?
            when canViewReservation(actor, reservation, field) &&
                (fieldFilter == null || reservation.fieldId == fieldFilter) &&
                (statusFilter == null || reservation.status == statusFilter))
          reservation,
    ];
    return _page(request, visible, (reservation) => reservation.toDto().toJson());
  }

  Future<Response> reservation(Request request) async {
    final (reservation, _) = await _visibleReservation(request, actorOf(request));
    return json(200, reservation.toDto().toJson());
  }

  Future<Response> createReservation(Request request) async {
    final actor = actorOf(request);
    if (!canCreateReservation(actor)) throw const Refused.forbidden();
    final object = await readObject(request);
    final body = parseBody(() => CreateReservationRequestDto.fromJson(object).toDomain());
    final field = await terenzo.getFieldById(body.fieldId);
    if (field == null || !canViewField(actor, field)) throw const Refused.notFound();
    final created = await terenzo.createReservation(
      fieldId: body.fieldId,
      userId: actor.id,
      startTime: body.startTime,
      endTime: body.endTime,
    );
    return json(201, created.toDto().toJson());
  }

  Future<Response> confirm(Request request) async {
    final actor = actorOf(request);
    final (reservation, field) = await _visibleReservation(request, actor);
    if (!canConfirmReservation(actor, reservation, field)) throw _refused(canConfirmReservation(actor, _asIf(reservation, ReservationStatus.pending), field));
    final confirmed = await terenzo.changeStatus(
      reservation.id,
      from: ReservationStatus.pending,
      to: ReservationStatus.confirmed,
    );
    await _notify(ReservationNotificationKind.confirmed, confirmed, field);
    return json(200, confirmed.toDto().toJson());
  }

  Future<Response> reject(Request request) async {
    final actor = actorOf(request);
    final (reservation, field) = await _visibleReservation(request, actor);
    if (!canRejectReservation(actor, reservation, field)) {
      throw _refused(canRejectReservation(actor, _asIf(reservation, ReservationStatus.pending), field));
    }
    final object = await readObject(request);
    final body = parseBody(() => ReservationReasonRequestDto.fromJson(object));
    final rejected = await terenzo.changeStatus(
      reservation.id,
      from: ReservationStatus.pending,
      to: ReservationStatus.cancelled,
      reason: body.reason,
    );
    await _notify(ReservationNotificationKind.rejected, rejected, field);
    return json(200, rejected.toDto().toJson());
  }

  Future<Response> cancel(Request request) async {
    final actor = actorOf(request);
    final (reservation, field) = await _visibleReservation(request, actor);
    if (!canCancelReservation(actor, reservation, field)) {
      throw _refused(canCancelReservation(actor, _asIf(reservation, ReservationStatus.confirmed), field));
    }
    final error = validateCancellationBy(user: actor, reservation: reservation, now: terenzo.now());
    if (error != null) throw ReservationRuleViolation(error);
    final cancelled = await terenzo.changeStatus(
      reservation.id,
      from: reservation.status,
      to: ReservationStatus.cancelled,
    );
    return json(200, cancelled.toDto().toJson());
  }

  Future<Response> checkIn(Request request) async {
    final actor = actorOf(request);
    final (reservation, field) = await _visibleReservation(request, actor);
    if (!canCheckInReservation(actor, reservation)) throw _refused(canCheckInReservation(actor, _asIf(reservation, ReservationStatus.confirmed)));
    return json(200, (await terenzo.checkIn(reservation.id)).toDto().toJson());
  }

  Future<Response> statistics(Request request) async {
    final actor = actorOf(request);
    if (!canViewStatistics(actor)) throw const Refused.forbidden();
    final periodCode = _optionalQuery(request, ApiQuery.period) ?? StatsPeriodCodes.week;
    final kind = parseBody(() => requireKnown(statsPeriodFromCode(periodCode), 'period', periodCode));
    final dayCode = _optionalQuery(request, ApiQuery.day);
    final day = dayCode == null ? terenzo.now().toLocal() : parseBody(() => _localDay(dayCode));
    final report = await terenzo.occupancy(
      StatsPeriod.of(kind, day),
      (field) => canViewFieldStatistics(actor, field),
    );
    return json(200, report.toDto().toJson());
  }

  Future<Response> users(Request request) async {
    if (!canManageUsers(actorOf(request))) throw const Refused.forbidden();
    final roleCode = _optionalQuery(request, ApiQuery.role);
    final role = roleCode == null ? null : parseBody(() => requireKnown(roleFromCode(roleCode), 'role', roleCode));
    final users = await terenzo.getUsers(role: role);
    return _page(request, users, (user) => user.toDto(includeContact: true).toJson());
  }

  Future<SportsField> _visibleField(Request request, AppUser? actor) async {
    final id = parseBody(() => int.parse(request.rawPathParameters[#id]!));
    final field = await terenzo.getFieldById(FieldId(id));
    if (field == null || !canViewField(actor, field)) throw const Refused.notFound();
    return field;
  }

  Future<(Reservation, SportsField)> _visibleReservation(Request request, AppUser actor) async {
    final id = parseBody(() => int.parse(request.rawPathParameters[#id]!));
    final reservation = await terenzo.getReservationById(ReservationId(id));
    if (reservation == null) throw const Refused.notFound();
    final field = await terenzo.getFieldById(reservation.fieldId);
    if (field == null || !canViewReservation(actor, reservation, field)) throw const Refused.notFound();
    return (reservation, field);
  }

  Exception _refused(bool roleMayAct) =>
      roleMayAct ? const ReservationRuleViolation(InvalidReservationStatus()) : const Refused.forbidden();

  Reservation _asIf(Reservation reservation, ReservationStatus status) => Reservation(
    id: reservation.id,
    fieldId: reservation.fieldId,
    userId: reservation.userId,
    startTime: reservation.startTime,
    endTime: reservation.endTime,
    totalPrice: reservation.totalPrice,
    status: status,
    createdAt: reservation.createdAt,
  );

  Future<void> _notify(ReservationNotificationKind kind, Reservation reservation, SportsField field) async {
    final recipient = await terenzo.getUserById(reservation.userId);
    if (recipient == null) return;
    await notifySafely(
      notifications,
      ReservationNotification(kind: kind, recipient: recipient, reservation: reservation, field: field),
    );
  }

  void _requireFieldValues(SaveFieldRequestDto body) {
    final errors = validateFieldDetails(
      name: body.name,
      address: body.address,
      city: body.city,
      pricePerHour: body.pricePerHour,
      contactPhone: body.contactPhone,
    );
    if (errors.isNotEmpty) {
      throw Refused(
        ErrorDto(
          code: ErrorCodes.badRequest,
          details: {ErrorDetailKeys.fields: [for (final error in errors) error.name]},
        ),
      );
    }
  }
}

Response _page<T>(Request request, List<T> items, Map<String, Object?> Function(T item) toJson) {
  final limit = parseBody(() => int.parse(_optionalQuery(request, ApiQuery.limit) ?? '${ApiPaging.defaultLimit}'));
  final offset = parseBody(() => int.parse(_optionalQuery(request, ApiQuery.offset) ?? '0'));
  if (limit < 1 || limit > ApiPaging.maxLimit) throw Refused.badRequest(ApiQuery.limit);
  if (offset < 0) throw Refused.badRequest(ApiQuery.offset);
  final pageItems = items.skip(offset).take(limit).toList();
  return json(
    200,
    PageDto(items: pageItems, total: items.length, limit: limit, offset: offset).toJson(toJson),
  );
}

String? _optionalQuery(Request request, String name) {
  final value = request.url.queryParameters[name];
  return value == null || value.trim().isEmpty ? null : value.trim();
}

String _query(Request request, String name) => _optionalQuery(request, name) ?? (throw Refused.badRequest(name));

DateTime? _optionalInstant(Request request, String name) {
  final value = _optionalQuery(request, name);
  return value == null ? null : parseBody(() => DateTime.parse(value));
}

DateTime _localDay(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw const FormatException('date');
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
}
