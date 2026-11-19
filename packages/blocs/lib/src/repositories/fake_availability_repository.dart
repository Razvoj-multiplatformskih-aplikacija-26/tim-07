import 'package:domain/domain.dart';

/// Slobodni termini iz memorije, bez servera. Računa ih isto pravilo kao na
/// serveru (`calculateAvailability`), nad rezervacijama koje drži izvor, radnim
/// vremenom i blokadama. Zamenljiv sa HTTP repozitorijumom bez izmene Bloc-a.
final class FakeAvailabilityRepository implements AvailabilityRepository {
  /// Izvor rezervacija svih korisnika.
  final ReservationRepository reservations;
  final Iterable<FieldSchedule> schedules;
  final Iterable<BlockedPeriod> blockedPeriods;
  final DateTime Function() _clock;

  FakeAvailabilityRepository({
    required this.reservations,
    required this.schedules,
    this.blockedPeriods = const [],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  Future<List<AvailabilitySlot>> getAvailability({
    required FieldId fieldId,
    required DateTime date,
  }) async {
    // Ko je zauzeo termin se ne vidi, samo da jeste.
    final onField = await reservations.getReservationsByField(fieldId);

    return calculateAvailability(
      fieldId: fieldId,
      date: date,
      schedules: schedules,
      reservations: onField,
      blockedPeriods: blockedPeriods,
      now: _clock(),
    );
  }
}
