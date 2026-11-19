import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';

enum ReservationNotificationKind { confirmed, rejected }

final class ReservationNotification {
  const ReservationNotification({
    required this.kind,
    required this.recipient,
    required this.reservation,
    required this.field,
  });

  final ReservationNotificationKind kind;
  final AppUser recipient;
  final Reservation reservation;
  final SportsField field;
}

abstract interface class NotificationGateway {
  Future<void> send(ReservationNotification notification);
}

final class NotificationFailed implements Exception {
  const NotificationFailed(this.reason);

  final String reason;

  @override
  String toString() => 'NotificationFailed($reason)';
}

final class FakeNotificationGateway implements NotificationGateway {
  FakeNotificationGateway({required this.apiKey, void Function(String message)? log}) : _log = log ?? stdout.writeln;

  final String apiKey;
  final void Function(String message) _log;
  final List<ReservationNotification> sent = [];

  @override
  Future<void> send(ReservationNotification notification) async {
    if (apiKey.isEmpty) throw const NotificationFailed('missing_api_key');
    sent.add(notification);
    final reservation = notification.reservation;
    _log(
      '[obavestenje] ${notification.kind.name} -> ${notification.recipient.email}: '
      'rezervacija #${reservation.id.value}, ${notification.field.name}, '
      '${reservation.startTime.toIso8601String()}',
    );
  }
}

Future<void> notifySafely(
  NotificationGateway gateway,
  ReservationNotification notification, {
  Duration timeout = const Duration(seconds: 5),
  void Function(String message)? logError,
}) async {
  try {
    await gateway.send(notification).timeout(timeout);
  } on Object catch (error) {
    (logError ?? stderr.writeln)(
      '[obavestenje] nije poslato (${notification.kind.name}, rezervacija #${notification.reservation.id.value}): $error',
    );
  }
}
