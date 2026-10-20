import 'package:domain/domain.dart';

String sportLabel(SportType sport) {
  return switch (sport) {
    SportType.football => 'Fudbal',
    SportType.basketball => 'Košarka',
    SportType.tennis => 'Tenis',
    SportType.padel => 'Padel',
    SportType.volleyball => 'Odbojka',
    SportType.swimming => 'Plivanje',
    SportType.futsal => 'Futsal',
    SportType.other => 'Ostalo',
  };
}

String paymentLabel(PaymentStatus status) {
  return switch (status) {
    PaymentStatus.unpaid => 'Nije plaćeno',
    PaymentStatus.paid => 'Plaćeno',
  };
}

String actionLabel(ReservationStatus from, ReservationStatus to) {
  return switch (to) {
    ReservationStatus.confirmed => 'Potvrdi',
    ReservationStatus.cancelled =>
      from == ReservationStatus.pending ? 'Odbij' : 'Otkaži',
    ReservationStatus.completed => 'Završi',
    ReservationStatus.pending => 'Vrati na čekanje',
  };
}

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}.';
}

String formatClock(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatTimeRange(DateTime start, DateTime end) =>
    '${formatClock(start)} - ${formatClock(end)}';

String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  if (hours == 0) {
    return '$minutes min';
  }

  return minutes == 0 ? '$hours h' : '$hours h $minutes min';
}

String formatPrice(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  return '$buffer din';
}
