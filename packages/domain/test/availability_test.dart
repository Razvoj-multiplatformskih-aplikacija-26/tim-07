import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const field = FieldId(1);
  final monday = DateTime(2030, 6, 3);

  FieldSchedule open(WeekDay day, int opens, int closes, {bool isOpen = true}) => FieldSchedule(
        fieldId: field,
        dayOfWeek: day,
        opensAt: TimeOfDay(hour: opens, minute: 0),
        closesAt: TimeOfDay(hour: closes, minute: 0),
        isOpen: isOpen,
      );

  Reservation reservation(int fromHour, int toHour, ReservationStatus status, {FieldId fieldId = field}) => Reservation(
        id: const ReservationId(1),
        fieldId: fieldId,
        userId: const UserId(1),
        startTime: DateTime(2030, 6, 3, fromHour),
        endTime: DateTime(2030, 6, 3, toHour),
        totalPrice: 0,
        status: status,
        createdAt: DateTime(2030, 6, 1),
      );

  List<SlotState> states({
    List<Reservation> reservations = const [],
    List<BlockedPeriod> blocked = const [],
    DateTime? now,
    List<FieldSchedule>? schedules,
  }) =>
      [
        for (final slot in availableSlots(
          fieldId: field,
          localDay: monday,
          schedules: schedules ?? [open(WeekDay.monday, 16, 22)],
          reservations: reservations,
          blockedPeriods: blocked,
          now: now ?? DateTime(2030, 6, 1),
        ))
          slot.state,
      ];

  test('termini od sat vremena kroz radno vreme', () {
    final slots = availableSlots(
      fieldId: field,
      localDay: monday,
      schedules: [open(WeekDay.monday, 16, 22)],
      reservations: const [],
      now: DateTime(2030, 6, 1),
    );

    expect(slots.map((s) => s.startTime.hour), [16, 17, 18, 19, 20, 21]);
    expect(slots.every((s) => s.state == SlotState.free), isTrue);
  });

  test('aktivna rezervacija zauzima termine, otkazana ne, tuđ teren ne smeta', () {
    expect(
      states(reservations: [
        reservation(18, 20, ReservationStatus.pending),
        reservation(16, 17, ReservationStatus.cancelled),
        reservation(21, 22, ReservationStatus.confirmed, fieldId: const FieldId(2)),
      ]),
      [SlotState.free, SlotState.free, SlotState.taken, SlotState.taken, SlotState.free, SlotState.free],
    );
  });

  test('blokada i prošlost', () {
    expect(
      states(
        blocked: [BlockedPeriod(fieldId: field, startTime: DateTime(2030, 6, 3, 20, 30), endTime: DateTime(2030, 6, 3, 21, 30))],
        now: DateTime(2030, 6, 3, 17, 30),
      ),
      [SlotState.past, SlotState.past, SlotState.free, SlotState.free, SlotState.blocked, SlotState.blocked],
    );
  });

  test('neradni dan i dan bez rasporeda nemaju termine', () {
    expect(states(schedules: [open(WeekDay.monday, 16, 22, isOpen: false)]), isEmpty);
    expect(states(schedules: [open(WeekDay.tuesday, 16, 22)]), isEmpty);
  });
}
