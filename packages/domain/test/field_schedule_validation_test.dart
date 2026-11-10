import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  const field = FieldId(1);

  FieldSchedule day(
    WeekDay dayOfWeek, {
    int opens = 8,
    int closes = 22,
    int opensMinute = 0,
    int closesMinute = 0,
    bool isOpen = true,
    FieldId fieldId = field,
  }) =>
      FieldSchedule(
        fieldId: fieldId,
        dayOfWeek: dayOfWeek,
        opensAt: TimeOfDay(hour: opens, minute: opensMinute),
        closesAt: TimeOfDay(hour: closes, minute: closesMinute),
        isOpen: isOpen,
      );

  ScheduleValidationError? validate(List<FieldSchedule> schedules) =>
      validateFieldSchedule(fieldId: field, schedules: schedules);

  test('ispravna nedelja sa neradnim danom prolazi', () {
    expect(
      validate([
        for (final d in WeekDay.values.take(6)) day(d),
        day(WeekDay.sunday, opens: 0, closes: 0, isOpen: false),
      ]),
      isNull,
    );
  });

  test('prazan raspored je ispravan (teren ne radi nijednog dana)', () {
    expect(validate(const []), isNull);
  });

  test('otvaranje mora biti pre zatvaranja', () {
    expect(validate([day(WeekDay.monday, opens: 22, closes: 8)]), isA<OpeningAfterClosing>());
    expect(validate([day(WeekDay.monday, opens: 10, closes: 10)]), isA<OpeningAfterClosing>());
    expect(
      validate([day(WeekDay.monday, opens: 10, closes: 10, closesMinute: 30)]),
      isNull,
    );
  });

  test('greška kaže koji dan nije ispravan', () {
    final error = validate([day(WeekDay.monday), day(WeekDay.tuesday, opens: 23, closes: 7)]);

    expect(error, isA<OpeningAfterClosing>());
    expect(error!.day, WeekDay.tuesday);
  });

  test('neradni dan se ne proverava po satima', () {
    expect(validate([day(WeekDay.monday, opens: 22, closes: 8, isOpen: false)]), isNull);
  });

  test('neispravno vreme u danu', () {
    expect(validate([day(WeekDay.monday, closes: 24)]), isA<InvalidTimeOfDay>());
    expect(validate([day(WeekDay.monday, opensMinute: 60)]), isA<InvalidTimeOfDay>());
  });

  test('isti dan dvaput', () {
    expect(validate([day(WeekDay.monday), day(WeekDay.monday)]), isA<DuplicateScheduleDay>());
  });

  test('raspored drugog terena', () {
    expect(
      validate([day(WeekDay.monday, fieldId: const FieldId(2))]),
      isA<ScheduleForOtherField>(),
    );
  });
}
