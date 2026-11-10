import 'package:domain/domain.dart';

enum ReservationNotificationKind { confirmed, rejected }

final class ReservationNotification {
  final ReservationNotificationKind kind;
  final AppUser recipient;
  final Reservation reservation;
  final SportsField field;

  const ReservationNotification({
    required this.kind,
    required this.recipient,
    required this.reservation,
    required this.field,
  });
}

abstract interface class NotificationGateway {
  Future<void> send(ReservationNotification notification);
}

final class NotificationFailed implements Exception {
  final String reason;

  const NotificationFailed(this.reason);

  @override
  String toString() => 'NotificationFailed($reason)';
}

final class FakeNotificationGateway implements NotificationGateway {
  final String apiKey;
  final void Function(String message) _log;
  final List<ReservationNotification> sent = [];

  FakeNotificationGateway({required this.apiKey, void Function(String message)? log})
      : _log = log ?? print;

  @override
  Future<void> send(ReservationNotification notification) async {
    if (apiKey.isEmpty) {
      throw const NotificationFailed('missing_api_key');
    }
    sent.add(notification);
    final reservation = notification.reservation;
    _log(
      '[obaveštenje] ${notification.kind.name} -> ${notification.recipient.email}: '
      'rezervacija #${reservation.id.value}, ${notification.field.name}, '
      '${reservation.startTime.toIso8601String()} - ${reservation.endTime.toIso8601String()}',
    );
  }
}
