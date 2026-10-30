import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  final fieldId = FieldId(1);
  final userId = UserId(1);
  final now = DateTime(2026, 11, 9, 10);
  // 10. 11. 2026. je utorak.
  final start = DateTime(2026, 11, 10, 18);
  final end = DateTime(2026, 11, 10, 19);

  final schedules = [
    for (final day in WeekDay.values)
      FieldSchedule(
        fieldId: fieldId,
        dayOfWeek: day,
        opensAt: const TimeOfDay(hour: 8, minute: 0),
        closesAt: const TimeOfDay(hour: 23, minute: 0),
      ),
  ];

  Reservation reservation({
    required DateTime startTime,
    required DateTime endTime,
    int user = 2,
    ReservationStatus status = ReservationStatus.confirmed,
  }) {
    return Reservation(
      id: ReservationId(10),
      fieldId: fieldId,
      userId: UserId(user),
      startTime: startTime,
      endTime: endTime,
      totalPrice: 3000,
      status: status,
      createdAt: DateTime(2026, 11, 1),
    );
  }

  ReservationValidationError? validate({
    DateTime? startTime,
    DateTime? endTime,
    List<Reservation> existing = const [],
    List<BlockedPeriod> blocked = const [],
    List<FieldSchedule>? fieldSchedules,
  }) {
    return validateReservationSlot(
      fieldId: fieldId,
      userId: userId,
      startTime: startTime ?? start,
      endTime: endTime ?? end,
      now: now,
      existingReservations: existing,
      schedules: fieldSchedules ?? schedules,
      blockedPeriods: blocked,
    );
  }

  group('Slobodan termin', () {
    test('slobodan termin u radnom vremenu prolazi', () {
      expect(validate(), isNull);
    });

    test('termin u proslosti vraca ReservationInPast', () {
      expect(
        validate(
          startTime: DateTime(2026, 11, 8, 18),
          endTime: DateTime(2026, 11, 8, 19),
        ),
        isA<ReservationInPast>(),
      );
    });

    test('kraj pre pocetka vraca InvalidTimeRange', () {
      expect(validate(endTime: start), isA<InvalidTimeRange>());
    });

    test(
      'preklapanje sa tudjom aktivnom rezervacijom vraca SlotAlreadyTaken',
      () {
        expect(
          validate(
            existing: [
              reservation(
                startTime: DateTime(2026, 11, 10, 18, 30),
                endTime: DateTime(2026, 11, 10, 19, 30),
              ),
            ],
          ),
          isA<SlotAlreadyTaken>(),
        );
      },
    );

    test('otkazana rezervacija ne zauzima termin', () {
      expect(
        validate(
          existing: [
            reservation(
              startTime: start,
              endTime: end,
              status: ReservationStatus.cancelled,
            ),
          ],
        ),
        isNull,
      );
    });

    test('blokiran period vraca FieldBlocked', () {
      expect(
        validate(
          blocked: [
            BlockedPeriod(
              fieldId: fieldId,
              startTime: DateTime(2026, 11, 10, 17),
              endTime: DateTime(2026, 11, 10, 20),
            ),
          ],
        ),
        isA<FieldBlocked>(),
      );
    });

    test('van radnog vremena vraca OutsideWorkingHours', () {
      expect(
        validate(
          startTime: DateTime(2026, 11, 10, 22, 30),
          endTime: DateTime(2026, 11, 10, 23, 30),
        ),
        isA<OutsideWorkingHours>(),
      );
    });

    test('bez rasporeda teren je zatvoren', () {
      expect(validate(fieldSchedules: const []), isA<OutsideWorkingHours>());
    });
  });

  group('Cena rezervacije', () {
    test('cena je proporcionalna trajanju', () {
      expect(
        calculateReservationPrice(
          pricePerHour: 3000,
          startTime: start,
          endTime: start.add(const Duration(minutes: 90)),
        ),
        4500,
      );
    });

    test('neispravan interval ima cenu nula', () {
      expect(
        calculateReservationPrice(
          pricePerHour: 3000,
          startTime: start,
          endTime: start,
        ),
        0,
      );
    });
  });
}
