
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final fieldId = FieldId(1);

  final blockedPeriods = [
    BlockedPeriod(
      fieldId: fieldId,
      startTime: DateTime(2026, 11, 10, 15),
      endTime: DateTime(2026, 11, 10, 17),
      reason: 'Odrzavanje terena',
    ),
  ];

  bool hasConflict({
    required DateTime start,
    required DateTime end,
    FieldId? requestedFieldId,
  }) {
    return hasBlockedPeriodOverlap(
      fieldId: requestedFieldId ?? fieldId,
      startTime: start,
      endTime: end,
      blockedPeriods: blockedPeriods,
    );
  }

  group('Blokirani termini terena', () {
    test('rezervacija unutar blokiranog termina nije dozvoljena', () {
      expect(
        hasConflict(
          start: DateTime(2026, 11, 10, 16),
          end: DateTime(2026, 11, 10, 17),
        ),
        isTrue,
      );
    });

    test('delimicno preklapanje nije dozvoljeno', () {
      expect(
        hasConflict(
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 10, 16),
        ),
        isTrue,
      );
    });

    test('rezervacija koja obuhvata celu blokadu nije dozvoljena', () {
      expect(
        hasConflict(
          start: DateTime(2026, 11, 10, 14),
          end: DateTime(2026, 11, 10, 18),
        ),
        isTrue,
      );
    });

    test('rezervacija koja se zavrsava na pocetku blokade je dozvoljena', () {
      expect(
        hasConflict(
          start: DateTime(2026, 11, 10, 13),
          end: DateTime(2026, 11, 10, 15),
        ),
        isFalse,
      );
    });

    test('rezervacija koja pocinje na kraju blokade je dozvoljena', () {
      expect(
        hasConflict(
          start: DateTime(2026, 11, 10, 17),
          end: DateTime(2026, 11, 10, 19),
        ),
        isFalse,
      );
    });

    test('blokada drugog terena ne utice na rezervaciju', () {
      expect(
        hasConflict(
          requestedFieldId: FieldId(2),
          start: DateTime(2026, 11, 10, 16),
          end: DateTime(2026, 11, 10, 17),
        ),
        isFalse,
      );
    });

    test('bez blokiranih termina nema konflikta', () {
      expect(
        hasBlockedPeriodOverlap(
          fieldId: fieldId,
          startTime: DateTime(2026, 11, 10, 16),
          endTime: DateTime(2026, 11, 10, 17),
          blockedPeriods: [],
        ),
        isFalse,
      );
    });
  });
}
