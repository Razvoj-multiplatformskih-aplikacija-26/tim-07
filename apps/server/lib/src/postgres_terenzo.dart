import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'terenzo_store.dart';

final class PostgresTerenzo
    implements
        ReservationRepository,
        SportsFieldRepository,
        FieldScheduleRepository,
        UserRepository,
        UserAdministrationRepository,
        StatisticsRepository,
        AvailabilityRepository {
  PostgresTerenzo(this._database, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Pool<void> _database;
  final DateTime Function() _clock;

  TerenzoStore get _store => TerenzoStore(_database);

  DateTime now() => _clock().toUtc();

  Future<void> refreshStatuses([Session? session]) async {
    final store = session == null ? _store : TerenzoStore(session);
    final at = now();
    for (final reservation in await store.activeStartingBefore(at.add(const Duration(hours: 5)))) {
      final resolved = resolveReservationStatus(reservation, at);
      if (resolved != reservation.status) {
        await store.changeStatus(reservation.id, from: reservation.status, to: resolved);
      }
    }
  }

  @override
  Future<List<Reservation>> getReservations() async {
    await refreshStatuses();
    return _store.reservations();
  }

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    await refreshStatuses();
    return _store.reservations(userId: userId);
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    await refreshStatuses();
    return _store.reservations(fieldId: fieldId);
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    await refreshStatuses();
    return _store.find(id);
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final timeError = validateReservationTime(startTime: startTime, endTime: endTime, now: now());
    if (timeError != null) throw ReservationRuleViolation(timeError);
    try {
      return await _database.runTx((tx) async {
        final store = TerenzoStore(tx);
        await refreshStatuses(tx);
        final field = await store.fieldForUpdate(fieldId) ?? (throw EntityNotFound('field', fieldId.value));
        if (await store.user(userId) == null) throw EntityNotFound('user', userId.value);
        if (!isFieldPublic(field)) throw const ReservationRuleViolation(FieldUnavailable());

        final error = validateReservationSlot(
          fieldId: fieldId,
          userId: userId,
          startTime: startTime.toLocal(),
          endTime: endTime.toLocal(),
          now: now().toLocal(),
          existingReservations: await store.activeOverlapping(
            fieldId: fieldId,
            userId: userId,
            from: startTime,
            to: endTime,
          ),
          schedules: await store.schedules([fieldId]),
          blockedPeriods: await store.blockedPeriods([fieldId], from: startTime, to: endTime),
        );
        if (error != null) throw ReservationRuleViolation(error);

        return store.insertReservation(
          fieldId: fieldId,
          userId: userId,
          startTime: startTime,
          endTime: endTime,
          totalPrice: calculateReservationPrice(
            pricePerHour: field.pricePerHour,
            startTime: startTime,
            endTime: endTime,
          ),
          status: field.confirmationMode == ConfirmationMode.automatic
              ? ReservationStatus.confirmed
              : ReservationStatus.pending,
          createdAt: now(),
        );
      });
    } on ServerException catch (error) {
      if (error.code == exclusionViolation) throw const ReservationRuleViolation(SlotAlreadyTaken());
      rethrow;
    }
  }

  Future<Reservation> changeStatus(
    ReservationId id, {
    required ReservationStatus to,
    ReservationStatus? from,
    String? reason,
  }) async {
    await refreshStatuses();
    final current = await _store.find(id) ?? (throw EntityNotFound('reservation', id.value));
    if (from != null && current.status != from) throw const ReservationRuleViolation(InvalidReservationStatus());
    if (to == ReservationStatus.completed || !canTransitionReservationStatus(current.status, to)) {
      throw const ReservationRuleViolation(InvalidReservationStatus());
    }
    if (!await _store.changeStatus(id, from: current.status, to: to, reason: reason)) {
      throw const ReservationRuleViolation(InvalidReservationStatus());
    }
    return (await _store.find(id))!;
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    if (status == ReservationStatus.cancelled) return cancelReservation(reservationId);
    return changeStatus(reservationId, to: status);
  }

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async {
    await refreshStatuses();
    final current = await _store.find(reservationId) ?? (throw EntityNotFound('reservation', reservationId.value));
    final error = validateCancellation(reservation: current, now: now());
    if (error != null) throw ReservationRuleViolation(error);
    return changeStatus(reservationId, from: current.status, to: ReservationStatus.cancelled);
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    await refreshStatuses();
    final current = await _store.find(reservationId) ?? (throw EntityNotFound('reservation', reservationId.value));
    final error = validateCheckIn(reservation: current, now: now());
    if (error != null) throw ReservationRuleViolation(error);
    if (!await _store.checkIn(reservationId, now())) {
      throw const ReservationRuleViolation(InvalidReservationStatus());
    }
    return (await _store.find(reservationId))!;
  }

  @override
  Future<List<SportsField>> getFields() => _store.fields();

  @override
  Future<List<SportsField>> getPublicFields() async => [
    for (final field in await _store.fields())
      if (isFieldPublic(field)) field,
  ];

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) async => [
    for (final field in await _store.fields())
      if (field.ownerId == ownerId) field,
  ];

  @override
  Future<SportsField?> getFieldById(FieldId id) => _store.field(id);

  @override
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  }) => _database.runTx((tx) async {
    final store = TerenzoStore(tx);
    final id = await store.insertField(
      ownerId: ownerId,
      name: name,
      description: description,
      sport: sport,
      address: address,
      city: city,
      pricePerHour: pricePerHour,
      contactPhone: contactPhone,
      confirmationMode: confirmationMode,
    );
    await store.replaceImages(id, imageUrls);
    return (await store.field(id))!;
  });

  @override
  Future<SportsField> updateField(SportsField field) => _database.runTx((tx) async {
    final store = TerenzoStore(tx);
    final current = await store.fieldForUpdate(field.id) ?? (throw EntityNotFound('field', field.id.value));
    await store.updateField(field, approvalStatus: approvalStatusAfterOwnerEdit(current.approvalStatus));
    await store.replaceImages(field.id, field.imageUrls);
    return (await store.field(field.id))!;
  });

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() async => [
    for (final field in await _store.fields())
      if (field.approvalStatus == ApprovalStatus.pending) field,
  ];

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) async {
    final current = await _store.field(fieldId) ?? (throw EntityNotFound('field', fieldId.value));
    if (decision == ApprovalStatus.pending || !canTransitionApprovalStatus(current.approvalStatus, decision)) {
      throw ApprovalTransitionNotAllowed(current.approvalStatus, decision);
    }
    final changed = await _store.review(
      fieldId,
      from: current.approvalStatus,
      to: decision,
      reviewer: reviewerId,
      at: now(),
      reason: reason,
    );
    if (!changed) {
      final latest = await _store.field(fieldId);
      throw ApprovalTransitionNotAllowed(latest?.approvalStatus ?? current.approvalStatus, decision);
    }
    return (await _store.field(fieldId))!;
  }

  Future<List<SportType>> publicSports() async {
    final sports = {for (final field in await getPublicFields()) field.sport};
    return [for (final sport in SportType.values) if (sports.contains(sport)) sport];
  }

  @override
  Future<List<FieldSchedule>> getSchedules(FieldId fieldId) => _store.schedules([fieldId]);

  @override
  Future<void> replaceSchedules(FieldId fieldId, List<FieldSchedule> schedules) async {
    final error = validateFieldSchedule(fieldId: fieldId, schedules: schedules);
    if (error != null) throw ScheduleRuleViolation(error);
    await _database.runTx((tx) async {
      final store = TerenzoStore(tx);
      if (await store.fieldForUpdate(fieldId) == null) throw EntityNotFound('field', fieldId.value);
      // Teren je zaključan, pa nova rezervacija ne može da uđe između provere i upisa.
      final conflict = validateScheduleAgainstReservations(
        fieldId: fieldId,
        schedules: schedules,
        reservations: await store.reservations(fieldId: fieldId),
        now: now().toLocal(),
      );
      if (conflict != null) throw ScheduleRuleViolation(conflict);
      await store.replaceSchedules(fieldId, schedules);
    });
  }

  @override
  Future<List<BlockedPeriod>> getBlockedPeriods(FieldId fieldId, {DateTime? from, DateTime? to}) =>
      _store.blockedPeriods([fieldId], from: from, to: to);

  @override
  Future<BlockedPeriod> addBlockedPeriod(BlockedPeriod period) => _database.runTx((tx) async {
    final store = TerenzoStore(tx);
    if (await store.fieldForUpdate(period.fieldId) == null) throw EntityNotFound('field', period.fieldId.value);
    final at = now();
    final overlapping = await store.reservationsOverlapping(
      [period.fieldId],
      from: period.startTime.isBefore(period.endTime) ? period.startTime : period.endTime,
      to: period.startTime.isBefore(period.endTime) ? period.endTime : period.startTime,
    );
    final error = validateBlockedPeriod(
      fieldId: period.fieldId,
      startTime: period.startTime,
      endTime: period.endTime,
      now: at,
      reservations: [
        for (final reservation in overlapping)
          reservation.copyWith(status: resolveReservationStatus(reservation, at)),
      ],
    );
    if (error != null) throw BlockedPeriodRuleViolation(error);
    return store.insertBlockedPeriod(period);
  });

  @override
  Future<void> removeBlockedPeriod(FieldId fieldId, BlockedPeriodId id) async {
    if (!await _store.deleteBlockedPeriod(fieldId, id)) throw EntityNotFound('blocked period', id.value);
  }

  @override
  Future<List<AvailabilitySlot>> getAvailability({required FieldId fieldId, required DateTime date}) async {
    await refreshStatuses();
    final day = DateTime(date.year, date.month, date.day);
    final next = DateTime(date.year, date.month, date.day + 1);
    return calculateAvailability(
      fieldId: fieldId,
      date: day,
      schedules: await _store.schedules([fieldId]),
      reservations: await _store.reservationsOverlapping([fieldId], from: day, to: next),
      blockedPeriods: await _store.blockedPeriods([fieldId], from: day, to: next),
      now: now().toLocal(),
    );
  }

  @override
  Future<AppUser?> getUserById(UserId id) => _store.user(id);

  @override
  Future<AppUser?> getUserByEmail(String email) async => (await _store.account(email))?.user;

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) => _store.users(role: role);

  @override
  Future<AppUser> setUserActive(UserId id, {required bool active}) async {
    final user = await _store.setUserActive(id, active: active);
    if (user == null) throw EntityNotFound('user', id.value);
    return user;
  }

  @override
  Future<OccupancyReport> getOccupancy({required StatsPeriod period, UserId? ownerId}) =>
      occupancy(period, (field) => ownerId == null || field.ownerId == ownerId);

  Future<OccupancyReport> occupancy(StatsPeriod period, bool Function(SportsField field) include) async {
    final fields = [
      for (final field in await _store.fields())
        if (include(field)) field,
    ];
    if (fields.isEmpty) return OccupancyReport(period: period, fields: const []);
    final ids = [for (final field in fields) field.id];
    final at = now();
    return calculateOccupancyReport(
      period: period,
      fields: fields,
      schedules: await _store.schedules(ids),
      reservations: [
        for (final reservation in await _store.reservationsOverlapping(ids, from: period.from, to: period.to))
          reservation.copyWith(status: resolveReservationStatus(reservation, at)),
      ],
      blockedPeriods: await _store.blockedPeriods(ids, from: period.from, to: period.to),
    );
  }
}
