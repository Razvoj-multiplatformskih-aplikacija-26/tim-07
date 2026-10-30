import 'package:domain/domain.dart';

String statusLabel(ReservationStatus status) {
  return switch (status) {
    ReservationStatus.pending => 'Na čekanju',
    ReservationStatus.confirmed => 'Potvrđena',
    ReservationStatus.completed => 'Završena',
    ReservationStatus.cancelled => 'Otkazana',
  };
}

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
    OutsideWorkingHours() => 'Termin je van radnog vremena terena.',
    FieldBlocked() => 'Teren je blokiran u izabranom terminu.',
    SlotAlreadyTaken() => 'Termin se preklapa sa postojećom rezervacijom.',
  };
}

String errorDetails(String message) => message.replaceFirst('Bad state: ', '');

String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}.';
}

String formatPrice(int amount) => '$amount RSD';

String formatClock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String formatTimeRange(DateTime start, DateTime end) {
  return '${formatClock(start)} - ${formatClock(end)}';
}
