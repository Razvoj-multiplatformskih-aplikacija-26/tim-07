
import 'package:flutter/foundation.dart';
import 'package:domain/domain.dart';

class MockReservation {
  final int id;
  final UserId userId;
  final String fieldName;
  final DateTime date;
  final String timeSlot;
  final String customerName;
  final int price;
  String status;

  MockReservation({
    required this.id,
    this.userId = const UserId(1),
    required this.fieldName,
    required this.date,
    required this.timeSlot,
    required this.customerName,
    required this.price,
    required this.status,
  });
}

class MockReservations {
  // Za KT1 koristimo jednog unapred prijavljenog korisnika.
  static const UserId currentUserId = UserId(1);
  static const String currentUserName = 'Marko Marković';

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static final List<MockReservation> reservations = [
    MockReservation(
      id: 1,
      userId: UserId(1),
      fieldName: 'Arena Fudbal',
      date: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '10:00 - 11:00',
      customerName: currentUserName,
      price: 3000,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 2,
      userId: UserId(2),
      fieldName: 'Basket Centar',
      date: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '12:00 - 13:00',
      customerName: 'Nikola Petrović',
      price: 1500,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 3,
      userId: UserId(1),
      fieldName: 'Tennis Club',
      date: DateTime.now().add(const Duration(days: 3)),
      timeSlot: '09:00 - 10:00',
      customerName: currentUserName,
      price: 2000,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 4,
      userId: UserId(2),
      fieldName: 'Padel Arena',
      date: DateTime.now().add(const Duration(days: 4)),
      timeSlot: '16:00 - 17:00',
      customerName: 'Stefan Ilić',
      price: 2500,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 5,
      userId: UserId(1),
      fieldName: 'Sport Zone',
      date: DateTime.now().add(const Duration(days: 5)),
      timeSlot: '18:00 - 19:00',
      customerName: currentUserName,
      price: 3500,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 6,
      userId: UserId(1),
      fieldName: 'Olimpijski Bazen',
      date: DateTime.now().subtract(const Duration(days: 1)),
      timeSlot: '11:00 - 12:00',
      customerName: currentUserName,
      price: 1200,
      status: 'Završena',
    ),
    MockReservation(
      id: 7,
      userId: UserId(2),
      fieldName: 'Volley Arena',
      date: DateTime.now().subtract(const Duration(days: 2)),
      timeSlot: '14:00 - 15:00',
      customerName: 'Jovana Stojanović',
      price: 1800,
      status: 'Završena',
    ),
    MockReservation(
      id: 8,
      userId: UserId(1),
      fieldName: 'Futsal Centar',
      date: DateTime.now().subtract(const Duration(days: 3)),
      timeSlot: '19:00 - 20:00',
      customerName: currentUserName,
      price: 2800,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 9,
      userId: UserId(1),
      fieldName: 'Tenis Akademija',
      date: DateTime.now().subtract(const Duration(days: 4)),
      timeSlot: '08:00 - 09:00',
      customerName: currentUserName,
      price: 2200,
      status: 'Završena',
    ),
    MockReservation(
      id: 10,
      userId: UserId(2),
      fieldName: 'Basket 3x3',
      date: DateTime.now().subtract(const Duration(days: 5)),
      timeSlot: '15:00 - 16:00',
      customerName: 'Filip Milošević',
      price: 1000,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 11,
      userId: UserId(1),
      fieldName: 'Arena Fudbal',
      date: DateTime.now().add(const Duration(days: 6)),
      timeSlot: '17:00 - 18:00',
      customerName: currentUserName,
      price: 3000,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 12,
      userId: UserId(1),
      fieldName: 'Basket Centar',
      date: DateTime.now().add(const Duration(days: 7)),
      timeSlot: '13:00 - 14:00',
      customerName: currentUserName,
      price: 1500,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 13,
      userId: UserId(2),
      fieldName: 'Tennis Club',
      date: DateTime.now().subtract(const Duration(days: 6)),
      timeSlot: '10:00 - 11:00',
      customerName: 'Miloš Ristić',
      price: 2000,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 14,
      userId: UserId(1),
      fieldName: 'Padel Arena',
      date: DateTime.now().subtract(const Duration(days: 7)),
      timeSlot: '12:00 - 13:00',
      customerName: currentUserName,
      price: 2500,
      status: 'Završena',
    ),
    MockReservation(
      id: 15,
      userId: UserId(1),
      fieldName: 'Sport Zone',
      date: DateTime.now().add(const Duration(days: 8)),
      timeSlot: '09:00 - 10:00',
      customerName: currentUserName,
      price: 3500,
      status: 'Potvrđena',
    ),
  ];

  static int _nextId = 16;

  static List<MockReservation> get myReservations {
    return reservations
        .where((reservation) => reservation.userId == currentUserId)
        .toList();
  }

  static void add({
    required String fieldName,
    required DateTime date,
    required String timeSlot,
    required String customerName,
    required int price,
  }) {
    reservations.add(
      MockReservation(
        id: _nextId++,
        userId: currentUserId,
        fieldName: fieldName,
        date: date,
        timeSlot: timeSlot,
        customerName: currentUserName,
        price: price,
        status: 'Na čekanju',
      ),
    );

    changes.value++;
  }

  static void cancel(int reservationId) {
    final index = reservations.indexWhere(
          (reservation) =>
      reservation.id == reservationId &&
          reservation.userId == currentUserId,
    );

    if (index == -1) {
      return;
    }

    final reservation = reservations[index];

    if (reservation.status == 'Završena' ||
        reservation.status == 'Otkazana') {
      return;
    }

    reservation.status = 'Otkazana';
    changes.value++;
  }
}
