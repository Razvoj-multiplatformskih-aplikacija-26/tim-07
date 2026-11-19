/// Stanje jednog termina terena za izabrani dan.
enum SlotState {
  /// Može da se rezerviše.
  free,

  /// Preklapa se sa aktivnom rezervacijom (ko je rezervisao, ne vidi se).
  taken,

  /// Vlasnik je blokirao teren (održavanje, događaj).
  blocked,

  /// Termin je već počeo ili prošao.
  past,
}

/// Jedan termin terena (obično sat vremena) sa stanjem.
final class AvailabilitySlot {
  final DateTime startTime;
  final DateTime endTime;
  final SlotState state;

  const AvailabilitySlot({
    required this.startTime,
    required this.endTime,
    required this.state,
  });

  bool get isFree => state == SlotState.free;

  Duration get duration => endTime.difference(startTime);
}
