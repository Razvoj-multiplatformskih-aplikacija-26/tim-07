import 'package:backoffice/text/labels.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Formatiranje datuma i vremena', () {
    final start = DateTime(2026, 3, 5, 9, 0);
    final end = DateTime(2026, 3, 5, 10, 30);

    expect(formatDate(start), '05.03.2026.');
    expect(formatTimeRange(start, end), '09:00 - 10:30');
  });

  test('Formatiranje trajanja', () {
    expect(formatDuration(const Duration(minutes: 45)), '45 min');
    expect(formatDuration(const Duration(hours: 2)), '2 h');
    expect(formatDuration(const Duration(minutes: 90)), '1 h 30 min');
  });

  test('Formatiranje cene', () {
    expect(formatPrice(500), '500 din');
    expect(formatPrice(3000), '3.000 din');
    expect(formatPrice(1250000), '1.250.000 din');
  });

  test('Naziv akcije zavisi od trenutnog statusa', () {
    expect(
      actionLabel(ReservationStatus.pending, ReservationStatus.confirmed),
      'Potvrdi',
    );
    expect(
      actionLabel(ReservationStatus.pending, ReservationStatus.cancelled),
      'Odbij',
    );
    expect(
      actionLabel(ReservationStatus.confirmed, ReservationStatus.cancelled),
      'Otkaži',
    );
  });
}
