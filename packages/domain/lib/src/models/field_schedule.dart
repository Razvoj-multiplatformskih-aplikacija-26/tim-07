
import '../enums.dart';
import '../ids.dart';

/// Predstavlja vreme u toku dana, bez datuma.
///
/// Primer: 08:30 ili 23:00.
final class TimeOfDay {
  final int hour;
  final int minute;

  const TimeOfDay({
    required this.hour,
    required this.minute,
  });

  /// Broj minuta od ponoći.
  int get totalMinutes => hour * 60 + minute;
}

/// Radno vreme terena za određeni dan u nedelji.
///
/// Jedan teren može imati različito radno vreme
/// ponedeljkom, utorkom, vikendom itd.
final class FieldSchedule {
  final FieldId fieldId;
  final WeekDay dayOfWeek;

  /// Početak radnog vremena.
  final TimeOfDay opensAt;

  /// Kraj radnog vremena.
  final TimeOfDay closesAt;

  /// Da li teren radi tog dana.
  final bool isOpen;

  const FieldSchedule({
    required this.fieldId,
    required this.dayOfWeek,
    required this.opensAt,
    required this.closesAt,
    this.isOpen = true,
  });
}

/// Period u kojem teren nije dostupan za rezervisanje.
///
/// Primer: održavanje terena ili privatni događaj.
final class BlockedPeriod {
  final FieldId fieldId;
  final DateTime startTime;
  final DateTime endTime;

  /// Opcioni razlog blokiranja.
  final String? reason;

  const BlockedPeriod({
    required this.fieldId,
    required this.startTime,
    required this.endTime,
    this.reason,
  });
}
