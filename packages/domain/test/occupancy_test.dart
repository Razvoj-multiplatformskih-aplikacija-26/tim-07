import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  SportsField field(int id, String name) => SportsField(
        id: FieldId(id),
        ownerId: const UserId(3),
        name: name,
        description: '',
        sport: SportType.football,
        address: '',
        city: 'Beograd',
        pricePerHour: 3000,
        contactPhone: '060',
        confirmationMode: ConfirmationMode.manual,
      );

  List<FieldSchedule> openDaily(int fieldId, {Set<WeekDay> closed = const {}}) => [
        for (final day in WeekDay.values)
          FieldSchedule(
            fieldId: FieldId(fieldId),
            dayOfWeek: day,
            opensAt: const TimeOfDay(hour: 8, minute: 0),
            closesAt: const TimeOfDay(hour: 22, minute: 0),
            isOpen: !closed.contains(day),
          ),
      ];

  var nextId = 1;
  Reservation reservation(int fieldId, DateTime start, DateTime end, ReservationStatus status) => Reservation(
        id: ReservationId(nextId++),
        fieldId: FieldId(fieldId),
        userId: const UserId(1),
        startTime: start,
        endTime: end,
        totalPrice: 0,
        status: status,
        createdAt: DateTime(2030, 5, 1),
      );

  final week = StatsPeriod.weekOf(DateTime(2030, 6, 5, 15));
  const dailyMinutes = 14 * 60;

  group('StatsPeriod', () {
    test('nedelja počinje u ponedeljak u ponoć i traje 7 dana', () {
      expect(week.from, DateTime(2030, 6, 3));
      expect(week.to, DateTime(2030, 6, 10));
      expect(StatsPeriod.weekOf(DateTime(2030, 6, 9, 23)).from, DateTime(2030, 6, 3));
    });

    test('mesec je od prvog do prvog u sledećem mesecu, i preko kraja godine', () {
      final june = StatsPeriod.monthOf(DateTime(2030, 6, 17));
      final december = StatsPeriod.of(StatsPeriodKind.month, DateTime(2030, 12, 31));

      expect((june.from, june.to), (DateTime(2030, 6), DateTime(2030, 7)));
      expect((december.from, december.to), (DateTime(2030, 12), DateTime(2031)));
    });
  });

  group('calculateFieldOccupancy', () {
    test('zauzetost se računa iz radnog vremena i rezervacija, otkazane ne zauzimaju', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: week,
        schedules: openDaily(1),
        reservations: [
          reservation(1, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 20), ReservationStatus.completed),
          reservation(1, DateTime(2030, 6, 4, 18), DateTime(2030, 6, 4, 19), ReservationStatus.confirmed),
          reservation(1, DateTime(2030, 6, 5, 18), DateTime(2030, 6, 5, 19), ReservationStatus.cancelled),
          reservation(2, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 20), ReservationStatus.completed),
        ],
      );

      expect(result.availableMinutes, 7 * dailyMinutes);
      expect(result.bookedMinutes, 180);
      expect(result.completedCount, 1);
      expect(result.cancelledCount, 1);
      expect(result.activeCount, 1);
      expect(result.occupancyPercent, 3);
    });

    test('neradni dan i blokada smanjuju raspoloživo vreme', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: week,
        schedules: openDaily(1, closed: {WeekDay.sunday}),
        reservations: const [],
        blockedPeriods: [
          BlockedPeriod(fieldId: const FieldId(1), startTime: DateTime(2030, 6, 3, 6), endTime: DateTime(2030, 6, 3, 10)),
          BlockedPeriod(fieldId: const FieldId(1), startTime: DateTime(2030, 6, 3, 9), endTime: DateTime(2030, 6, 3, 12)),
          BlockedPeriod(fieldId: const FieldId(2), startTime: DateTime(2030, 6, 4, 8), endTime: DateTime(2030, 6, 4, 22)),
        ],
      );

      expect(result.availableMinutes, 6 * dailyMinutes - 4 * 60);
    });

    test('rezervacija preko granice perioda računa se samo unutar perioda', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: StatsPeriod.weekOf(DateTime(2030, 6, 10)),
        schedules: [
          for (final day in WeekDay.values)
            FieldSchedule(
              fieldId: const FieldId(1),
              dayOfWeek: day,
              opensAt: const TimeOfDay(hour: 0, minute: 0),
              closesAt: const TimeOfDay(hour: 23, minute: 59),
            ),
        ],
        reservations: [
          reservation(1, DateTime(2030, 6, 9, 22), DateTime(2030, 6, 10, 1), ReservationStatus.confirmed),
        ],
      );

      expect(result.bookedMinutes, 60);
      expect(result.activeCount, 0);
    });

    test('vreme u blokadi se ne računa kao zauzeto, pa zauzetost ne prelazi 100 %', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: week,
        schedules: [
          FieldSchedule(
            fieldId: const FieldId(1),
            dayOfWeek: WeekDay.monday,
            opensAt: const TimeOfDay(hour: 8, minute: 0),
            closesAt: const TimeOfDay(hour: 10, minute: 0),
          ),
        ],
        reservations: [
          reservation(1, DateTime(2030, 6, 3, 8), DateTime(2030, 6, 3, 10), ReservationStatus.confirmed),
        ],
        blockedPeriods: [
          BlockedPeriod(fieldId: const FieldId(1), startTime: DateTime(2030, 6, 3, 9), endTime: DateTime(2030, 6, 3, 10)),
        ],
      );

      expect(result.availableMinutes, 60);
      expect(result.bookedMinutes, 60);
      expect(result.occupancyPercent, 100);
    });

    test('teren bez radnog vremena ima 0 % umesto deljenja nulom', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: week,
        schedules: const [],
        reservations: const [],
      );

      expect(result.availableMinutes, 0);
      expect(result.occupancyPercent, 0);
    });

    test('nedelja sa promenom letnjeg vremena ima isto radno vreme po danu', () {
      final result = calculateFieldOccupancy(
        field: field(1, 'Arena'),
        period: StatsPeriod.weekOf(DateTime(2030, 10, 27)),
        schedules: openDaily(1),
        reservations: const [],
      );

      expect(result.availableMinutes, 7 * dailyMinutes);
    });
  });

  test('izveštaj sabira terene i ređa ih po imenu', () {
    final report = calculateOccupancyReport(
      period: week,
      fields: [field(2, 'Tenis'), field(1, 'Arena')],
      schedules: [...openDaily(1), ...openDaily(2)],
      reservations: [
        reservation(1, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 20), ReservationStatus.completed),
        reservation(2, DateTime(2030, 6, 3, 18), DateTime(2030, 6, 3, 19), ReservationStatus.completed),
        reservation(2, DateTime(2030, 6, 4, 18), DateTime(2030, 6, 4, 19), ReservationStatus.cancelled),
      ],
    );

    expect(report.fields.map((f) => f.fieldName), ['Arena', 'Tenis']);
    expect(report.availableMinutes, 2 * 7 * dailyMinutes);
    expect(report.bookedMinutes, 180);
    expect(report.completedCount, 2);
    expect(report.cancelledCount, 1);
  });
}
