import 'dart:async';

import 'package:domain/domain.dart';

import '../db/mysql_reservation_repository.dart';
import '../notifications/notification_gateway.dart';

final class ReservationDecisions {
  final MySqlReservationRepository reservations;
  final SportsFieldRepository fields;
  final UserRepository users;
  final NotificationGateway notifications;
  final Duration notificationTimeout;
  final void Function(String message) _logError;

  ReservationDecisions({
    required this.reservations,
    required this.fields,
    required this.users,
    required this.notifications,
    this.notificationTimeout = const Duration(seconds: 5),
    void Function(String message)? logError,
  }) : _logError = logError ?? print;

  Future<Reservation> confirm(ReservationId id) async {
    final confirmed = await reservations.changeStatus(
      reservationId: id,
      from: ReservationStatus.pending,
      to: ReservationStatus.confirmed,
    );
    await _notify(ReservationNotificationKind.confirmed, confirmed);
    return confirmed;
  }

  Future<Reservation> reject(ReservationId id, {String? reason}) async {
    final rejected = await reservations.changeStatus(
      reservationId: id,
      from: ReservationStatus.pending,
      to: ReservationStatus.cancelled,
      reason: reason,
    );
    await _notify(ReservationNotificationKind.rejected, rejected);
    return rejected;
  }

  Future<void> _notify(ReservationNotificationKind kind, Reservation reservation) async {
    try {
      final recipient = await users.getUserById(reservation.userId);
      final field = await fields.getFieldById(reservation.fieldId);
      if (recipient == null || field == null) {
        throw const NotificationFailed('missing_recipient_or_field');
      }
      await notifications
          .send(ReservationNotification(
            kind: kind,
            recipient: recipient,
            reservation: reservation,
            field: field,
          ))
          .timeout(notificationTimeout);
    } on Object catch (error) {
      _logError(
        '[obaveštenje] nije poslato (${kind.name}, rezervacija #${reservation.id.value}): $error',
      );
    }
  }
}
