/// Cena rezervacije u dinarima, proporcionalna trajanju termina.
///
/// Primer: sat košta 3000, termin od 90 minuta košta 4500.
int calculateReservationPrice({
  required int pricePerHour,
  required DateTime startTime,
  required DateTime endTime,
}) {
  final minutes = endTime.difference(startTime).inMinutes;

  if (minutes <= 0) {
    return 0;
  }

  return (pricePerHour * minutes / 60).round();
}
