
import 'package:domain/domain.dart';

/// Demo podaci za testiranje Terenzo aplikacije.
///
/// Termini se generisu u odnosu na trenutni datum,
/// kako bi primeri ostali upotrebljivi i kasnije.
abstract final class DemoData {
  static final fields = <SportsField>[
    SportsField(
      id: FieldId(1),
      ownerId: UserId(10),
      name: 'Arena Fudbal',
      description: 'Teren za mali fudbal sa vestackom travom.',
      address: 'Bulevar kralja Aleksandra 100',
      city: 'Beograd',
      contactPhone: '0601234567',
      sport: SportType.football,
      pricePerHour: 3000,
      imageUrls: const [],
      confirmationMode: ConfirmationMode.automatic,
      isActive: true,
    ),
    SportsField(
      id: FieldId(2),
      ownerId: UserId(11),
      name: 'Tenis Centar',
      description: 'Otvoreni teniski teren.',
      address: 'Bulevar oslobodjenja 50',
      city: 'Novi Sad',
      contactPhone: '0602345678',
      sport: SportType.tennis,
      pricePerHour: 2000,
      imageUrls: const [],
      confirmationMode: ConfirmationMode.manual,
      isActive: true,
    ),
    SportsField(
      id: FieldId(3),
      ownerId: UserId(12),
      name: 'Basket Park',
      description: 'Kosarkaski teren za rekreaciju.',
      address: 'Nemanjina 15',
      city: 'Beograd',
      contactPhone: '0603456789',
      sport: SportType.basketball,
      pricePerHour: 1500,
      imageUrls: const [],
      confirmationMode: ConfirmationMode.automatic,
      isActive: true,
    ),
  ];

  static final schedules = <FieldSchedule>[
    for (final field in fields)
      for (final day in WeekDay.values)
        FieldSchedule(
          fieldId: field.id,
          dayOfWeek: day,
          opensAt: const TimeOfDay(hour: 8, minute: 0),
          closesAt: const TimeOfDay(hour: 23, minute: 0),
          isOpen: true,
        ),
  ];

  static List<Reservation> createReservations({DateTime? now}) {
    final current = now ?? DateTime.now();

    // Sutrasnji datum.
    final tomorrow = DateTime(
      current.year,
      current.month,
      current.day + 1,
    );

    // Datum za tri dana.
    final inThreeDays = DateTime(
      current.year,
      current.month,
      current.day + 3,
    );

    return [
      Reservation(
        id: ReservationId(1),
        fieldId: FieldId(1),
        userId: UserId(1),
        startTime: tomorrow.add(const Duration(hours: 18)),
        endTime: tomorrow.add(const Duration(hours: 20)),
        totalPrice: 6000,
        status: ReservationStatus.confirmed,
        createdAt: current,
      ),
      Reservation(
        id: ReservationId(2),
        fieldId: FieldId(2),
        userId: UserId(2),
        startTime: inThreeDays.add(const Duration(hours: 16)),
        endTime: inThreeDays.add(const Duration(hours: 17)),
        totalPrice: 2000,
        status: ReservationStatus.pending,
        createdAt: current,
      ),
      Reservation(
        id: ReservationId(3),
        fieldId: FieldId(3),
        userId: UserId(1),
        startTime: inThreeDays.add(const Duration(hours: 19)),
        endTime: inThreeDays.add(const Duration(hours: 21)),
        totalPrice: 3000,
        status: ReservationStatus.confirmed,
        createdAt: current,
      ),
    ];
  }

  static final blockedPeriods = <BlockedPeriod>[];
}
