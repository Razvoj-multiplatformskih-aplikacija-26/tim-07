
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final fieldId = FieldId(1);

  // 10. novembar 2026. je utorak.
  final schedules = [
    FieldSchedule(
      fieldId: fieldId,
      dayOfWeek: WeekDay.tuesday,
      opensAt: const TimeOfDay(hour: 9, minute: 0),
      closesAt: const TimeOfDay(hour: 22, minute: 0),
    ),
    FieldSchedule(
      fieldId: fieldId,
      dayOfWeek: WeekDay.wednesday,
      opensAt: const TimeOfDay(hour: 0, minute: 0),
      closesAt: const TimeOfDay(hour: 22, minute: 0),
    ),
    FieldSchedule(
      fieldId: fieldId,
      dayOfWeek: WeekDay.thursday,
      opensAt: const TimeOfDay(hour: 9, minute: 0),
      closesAt: const TimeOfDay(hour: 22, minute: 0),
      isOpen: false,
    ),
  ];

  bool isAllowed({
    required DateTime start,
    required DateTime end,
    FieldId? requestedFieldId,
  }) {
    return isReservationWithinWorkingHours(
      fieldId: requestedFieldId ?? fieldId,
      startTime: start,
      endTime: end,
      schedules: schedules,
    );
  }

  group('Radno vreme terena', () {
    test('rezervacija unutar radnog vremena je dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 10, 16),
        ),
        isTrue,
      );
    });

    test('rezervacija tacno od otvaranja je dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 9),
          end: DateTime(2026, 11, 10, 11),
        ),
        isTrue,
      );
    });

    test('rezervacija tacno do zatvaranja je dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 20),
          end: DateTime(2026, 11, 10, 22),
        ),
        isTrue,
      );
    });

    test('rezervacija pre otvaranja nije dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 8),
          end: DateTime(2026, 11, 10, 10),
        ),
        isFalse,
      );
    });

    test('rezervacija posle zatvaranja nije dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 21),
          end: DateTime(2026, 11, 10, 23),
        ),
        isFalse,
      );
    });

    test('teren zatvoren tog dana ne prihvata rezervacije', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 12, 14),
          end: DateTime(2026, 11, 12, 16),
        ),
        isFalse,
      );
    });

    test('dan bez rasporeda ne prihvata rezervacije', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 13, 14),
          end: DateTime(2026, 11, 13, 16),
        ),
        isFalse,
      );
    });

    test('rezervacija preko ponoci proverava oba dana', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 21),
          end: DateTime(2026, 11, 11, 1),
        ),
        isFalse,
      );
    });

    test('rezervacija sa istim pocetkom i krajem nije dozvoljena', () {
      expect(
        isAllowed(
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 10, 14),
        ),
        isFalse,
      );
    });

    test('raspored drugog terena ne vazi za ovaj teren', () {
      expect(
        isAllowed(
          requestedFieldId: FieldId(2),
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 10, 16),
        ),
        isFalse,
      );
    });
  });
}
