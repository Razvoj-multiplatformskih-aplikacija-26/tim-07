import 'package:domain/domain.dart';

String statusLabel(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.pending => 'Na čekanju',
    ReservationStatus.confirmed => 'Potvrđena',
    ReservationStatus.completed => 'Završena',
    ReservationStatus.cancelled => 'Otkazana',
  };
}

String validationMessage(ReservationValidationError error) {
  return switch (error) {
    InvalidTimeRange() => 'Kraj termina mora biti posle početka.',
    ReservationInPast() => 'Termin rezervacije mora biti u budućnosti.',
    CheckInNotAllowed() =>
      'Dolazak je moguće potvrditi od 24 do 5 sati pre početka termina.',
    CancellationDeadlineExpired() =>
      'Rezervaciju nije moguće otkazati manje od 5 sati pre početka.',
    InvalidReservationStatus() =>
      'Trenutni status rezervacije ne dozvoljava ovu radnju.',
    InvalidReservationDuration() => 'Trajanje rezervacije mora biti pozitivno.',
  };
}

String errorDetails(String message) => message.replaceFirst('Bad state: ', '');

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}.';
}

String formatTimeRange(DateTime start, DateTime end) {
  String clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  return '${clock(start)} - ${clock(end)}';
}
