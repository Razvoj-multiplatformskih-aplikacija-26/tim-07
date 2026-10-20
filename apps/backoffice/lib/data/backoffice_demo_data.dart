import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

/// Demo podaci za backoffice aplikaciju.
///
/// Tereni i radno vreme dolaze iz zajednickog [DemoData],
/// a backoffice ima sopstveni, veci skup rezervacija
/// kako bi tabela, detalji i akcije imali sta da prikazu.
abstract final class BackofficeDemoData {
  /// Korisnici koji su napravili rezervacije.
  static final users = <AppUser>[
    AppUser(
      id: const UserId(1),
      firstName: 'Jovan',
      lastName: 'Petrovic',
      email: 'jovan.petrovic@example.com',
      phoneNumber: '0641111111',
      dateOfBirth: DateTime(1999, 3, 2),
      role: UserRole.user,
      createdAt: DateTime(2025, 2, 1),
    ),
    AppUser(
      id: const UserId(2),
      firstName: 'Ana',
      lastName: 'Jovanovic',
      email: 'ana.jovanovic@example.com',
      phoneNumber: '0642222222',
      dateOfBirth: DateTime(2001, 7, 19),
      role: UserRole.user,
      createdAt: DateTime(2025, 3, 10),
    ),
    AppUser(
      id: const UserId(3),
      firstName: 'Nikola',
      lastName: 'Ilic',
      email: 'nikola.ilic@example.com',
      phoneNumber: '0643333333',
      dateOfBirth: DateTime(1997, 11, 5),
      role: UserRole.user,
      createdAt: DateTime(2025, 4, 22),
    ),
    AppUser(
      id: const UserId(4),
      firstName: 'Milica',
      lastName: 'Savic',
      email: 'milica.savic@example.com',
      phoneNumber: '0644444444',
      dateOfBirth: DateTime(2000, 1, 30),
      role: UserRole.user,
      createdAt: DateTime(2025, 5, 14),
    ),
  ];

  static List<SportsField> get fields => DemoData.fields;

  static List<FieldSchedule> get schedules => DemoData.schedules;

  static List<BlockedPeriod> get blockedPeriods => DemoData.blockedPeriods;

  /// Rezervacije u odnosu na trenutni datum.
  ///
  /// Sadrze sve statuse: na cekanju, potvrdjene,
  /// zavrsene i otkazane.
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

  /// Ime korisnika za prikaz u tabeli i detaljima.
  static String userName(UserId id) {
    for (final user in users) {
      if (user.id == id) {
        return user.fullName;
      }
    }

    return 'Korisnik #${id.value}';
  }

  /// Naziv terena za prikaz u tabeli i detaljima.
  static String fieldName(FieldId id) {
    for (final field in fields) {
      if (field.id == id) {
        return field.name;
      }
    }

    return 'Teren #${id.value}';
  }
}
