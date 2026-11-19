import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

abstract final class BackofficeDemoData {
  static final users = <AppUser>[
    AppUser(
      id: const UserId(1),
      firstName: 'Jovan',
      lastName: 'Petrović',
      email: 'jovan.petrovic@example.com',
      phoneNumber: '0641111111',
      dateOfBirth: DateTime(1999, 3, 2),
      role: UserRole.user,
      createdAt: DateTime(2025, 2, 1),
    ),
    AppUser(
      id: const UserId(2),
      firstName: 'Ana',
      lastName: 'Jovanović',
      email: 'ana.jovanovic@example.com',
      phoneNumber: '0642222222',
      dateOfBirth: DateTime(2001, 7, 19),
      role: UserRole.user,
      createdAt: DateTime(2025, 3, 10),
    ),
    AppUser(
      id: const UserId(3),
      firstName: 'Nikola',
      lastName: 'Ilić',
      email: 'nikola.ilic@example.com',
      phoneNumber: '0643333333',
      dateOfBirth: DateTime(1997, 11, 5),
      role: UserRole.user,
      createdAt: DateTime(2025, 4, 22),
    ),
    AppUser(
      id: const UserId(4),
      firstName: 'Milica',
      lastName: 'Savić',
      email: 'milica.savic@example.com',
      phoneNumber: '0644444444',
      dateOfBirth: DateTime(2000, 1, 30),
      role: UserRole.user,
      createdAt: DateTime(2025, 5, 14),
    ),
  ];

  /// Vlasnik kao koga radi demo backoffice dok nema prijave (T51). Prava su
  /// njegova: vidi i blokira samo svoje terene.
  static final owner = AppUser(
    id: const UserId(10),
    firstName: 'Petar',
    lastName: 'Vlasnik',
    email: 'petar.vlasnik@example.com',
    phoneNumber: '0645555555',
    dateOfBirth: DateTime(1985, 6, 1),
    role: UserRole.owner,
    createdAt: DateTime(2025, 1, 10),
  );

  /// Demo tereni, svi u vlasništvu demo vlasnika.
  static List<SportsField> get fields => [
        for (final field in DemoData.fields)
          SportsField(
            id: field.id,
            ownerId: owner.id,
            name: field.name,
            description: field.description,
            sport: field.sport,
            address: field.address,
            city: field.city,
            pricePerHour: field.pricePerHour,
            contactPhone: field.contactPhone,
            imageUrls: field.imageUrls,
            confirmationMode: field.confirmationMode,
            isActive: field.isActive,
            approvalStatus: field.approvalStatus,
          ),
      ];

  static List<FieldSchedule> get schedules => DemoData.schedules;

  /// Demo blokade u narednim danima, u odnosu na dan kada se aplikacija pokrene.
  static List<BlockedPeriod> createBlockedPeriods({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    return [
      BlockedPeriod(
        fieldId: const FieldId(1),
        startTime: today.add(const Duration(days: 3, hours: 8)),
        endTime: today.add(const Duration(days: 3, hours: 12)),
        reason: 'Održavanje terena',
      ),
      BlockedPeriod(
        fieldId: const FieldId(2),
        startTime: today.add(const Duration(days: 5, hours: 18)),
        endTime: today.add(const Duration(days: 5, hours: 22)),
        reason: 'Turnir',
      ),
    ];
  }

  static List<BlockedPeriod> get blockedPeriods => createBlockedPeriods();

  static List<Reservation> createReservations({DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    DateTime at(int dayOffset, int hour) =>
        today.add(Duration(days: dayOffset, hours: hour));

    Reservation reservation({
      required int id,
      required int fieldId,
      required int userId,
      required int dayOffset,
      required int startHour,
      required int hours,
      required int pricePerHour,
      required ReservationStatus status,
    }) {
      return Reservation(
        id: ReservationId(id),
        fieldId: FieldId(fieldId),
        userId: UserId(userId),
        startTime: at(dayOffset, startHour),
        endTime: at(dayOffset, startHour + hours),
        totalPrice: pricePerHour * hours,
        status: status,
        createdAt: current.subtract(const Duration(days: 7)),
      );
    }

    return [
      reservation(
        id: 1,
        fieldId: 1,
        userId: 1,
        dayOffset: 1,
        startHour: 18,
        hours: 2,
        pricePerHour: 3000,
        status: ReservationStatus.confirmed,
      ),
      reservation(
        id: 2,
        fieldId: 2,
        userId: 2,
        dayOffset: 3,
        startHour: 16,
        hours: 1,
        pricePerHour: 2000,
        status: ReservationStatus.pending,
      ),
      reservation(
        id: 3,
        fieldId: 3,
        userId: 1,
        dayOffset: 3,
        startHour: 19,
        hours: 2,
        pricePerHour: 1500,
        status: ReservationStatus.confirmed,
      ),
      reservation(
        id: 4,
        fieldId: 2,
        userId: 3,
        dayOffset: 2,
        startHour: 10,
        hours: 1,
        pricePerHour: 2000,
        status: ReservationStatus.pending,
      ),
      reservation(
        id: 5,
        fieldId: 1,
        userId: 4,
        dayOffset: 4,
        startHour: 20,
        hours: 1,
        pricePerHour: 3000,
        status: ReservationStatus.pending,
      ),
      reservation(
        id: 6,
        fieldId: 3,
        userId: 2,
        dayOffset: -2,
        startHour: 17,
        hours: 1,
        pricePerHour: 1500,
        status: ReservationStatus.completed,
      ),
      reservation(
        id: 7,
        fieldId: 1,
        userId: 3,
        dayOffset: 5,
        startHour: 9,
        hours: 2,
        pricePerHour: 3000,
        status: ReservationStatus.cancelled,
      ),
    ];
  }

  static AppUser? userById(UserId id) {
    for (final user in users) {
      if (user.id == id) {
        return user;
      }
    }

    return null;
  }

  static SportsField? fieldById(FieldId id) {
    for (final field in fields) {
      if (field.id == id) {
        return field;
      }
    }

    return null;
  }

  static String userName(UserId id) =>
      userById(id)?.fullName ?? 'Korisnik #${id.value}';

  static String fieldName(FieldId id) =>
      fieldById(id)?.name ?? 'Teren #${id.value}';
}
