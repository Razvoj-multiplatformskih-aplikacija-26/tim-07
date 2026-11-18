import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

abstract final class MobileDemoData {
  /// Lozinka svih demo naloga. Samo za demo: pravi nalozi su na serveru (KT2).
  static const demoPassword = 'lozinka123';

  /// Demo nalozi. Rezervacije ispod pripadaju korisnicima sa id 1 i 2.
  /// Vlasnik služi da se vidi da mobilna aplikacija ne prima osoblje.
  static final accounts = <FakeAccount>[
    _account(1, 'Marko', 'Marković', 'marko.markovic@example.com', UserRole.user),
    _account(2, 'Jelena', 'Nikolić', 'jelena.nikolic@example.com', UserRole.user),
    _account(101, 'Petar', 'Vlasnik', 'petar.vlasnik@example.com', UserRole.owner),
  ];

  static FakeAccount _account(
    int id,
    String firstName,
    String lastName,
    String email,
    UserRole role,
  ) {
    return FakeAccount(
      password: demoPassword,
      user: AppUser(
        id: UserId(id),
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: '060000000$id',
        dateOfBirth: DateTime(1995, 1, 1),
        role: role,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  }

  static final fields = <SportsField>[
    _field(1, 'Arena Fudbal', 'Novi Beograd', SportType.football, 3500),
    _field(2, 'Basket Centar', 'Voždovac', SportType.basketball, 2000),
    _field(3, 'Tennis Club', 'Zemun', SportType.tennis, 2500),
    _field(4, 'Padel Arena', 'Dorćol', SportType.padel, 3000),
    _field(5, 'Sport Zone', 'Banovo brdo', SportType.football, 4000),
    _field(6, 'Olimpijski Bazen', 'Vračar', SportType.swimming, 1800),
    _field(7, 'Volley Arena', 'Zvezdara', SportType.volleyball, 2800),
    _field(8, 'Futsal Centar', 'Zemun', SportType.futsal, 3200),
    _field(9, 'Tenis Akademija', 'Novi Beograd', SportType.tennis, 2200),
    _field(10, 'Basket 3x3', 'Karaburma', SportType.basketball, 1500),
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

  static SportsField _field(
    int id,
    String name,
    String city,
    SportType sport,
    int price,
  ) {
    return SportsField(
      id: FieldId(id),
      ownerId: UserId(100 + id),
      name: name,
      description: 'Sportski teren za rekreaciju i organizovane termine.',
      address: city,
      city: 'Beograd',
      contactPhone: '0601234567',
      sport: sport,
      pricePerHour: price,
      confirmationMode: ConfirmationMode.manual,
    );
  }

  static SportsField? fieldById(FieldId id) {
    for (final field in fields) {
      if (field.id == id) {
        return field;
      }
    }
    return null;
  }

  static String fieldName(FieldId id) {
    for (final field in fields) {
      if (field.id == id) {
        return field.name;
      }
    }
    return 'Teren #${id.value}';
  }

  static List<Reservation> createReservations({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    Reservation reservation(
      int id,
      int userId,
      int fieldId,
      int dayOffset,
      int startHour,
      int price,
      ReservationStatus status,
    ) {
      final start = today.add(Duration(days: dayOffset, hours: startHour));

      return Reservation(
        id: ReservationId(id),
        fieldId: FieldId(fieldId),
        userId: UserId(userId),
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        totalPrice: price,
        status: status,
        createdAt: start.subtract(const Duration(days: 2)),
      );
    }

    const pending = ReservationStatus.pending;
    const confirmed = ReservationStatus.confirmed;
    const completed = ReservationStatus.completed;
    const cancelled = ReservationStatus.cancelled;

    return [
      reservation(1, 1, 1, 1, 10, 3000, pending),
      reservation(2, 2, 2, 2, 12, 1500, confirmed),
      reservation(3, 1, 3, 3, 9, 2000, pending),
      reservation(4, 2, 4, 4, 16, 2500, confirmed),
      reservation(5, 1, 5, 5, 18, 3500, pending),
      reservation(6, 1, 6, -1, 11, 1200, completed),
      reservation(7, 2, 7, -2, 14, 1800, completed),
      reservation(8, 1, 8, -3, 19, 2800, cancelled),
      reservation(9, 1, 9, -4, 8, 2200, completed),
      reservation(10, 2, 10, -5, 15, 1000, cancelled),
      reservation(11, 1, 1, 6, 17, 3000, confirmed),
      reservation(12, 1, 2, 7, 13, 1500, pending),
      reservation(13, 2, 3, -6, 10, 2000, cancelled),
      reservation(14, 1, 4, -7, 12, 2500, completed),
      reservation(15, 1, 5, 8, 9, 3500, confirmed),
    ];
  }
}
