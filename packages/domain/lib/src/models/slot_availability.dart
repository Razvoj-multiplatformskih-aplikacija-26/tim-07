enum SlotState { free, taken, blocked, past }

final class SlotAvailability {
  final DateTime startTime;
  final DateTime endTime;
  final SlotState state;

  const SlotAvailability({required this.startTime, required this.endTime, required this.state});
}
