
import 'package:flutter/foundation.dart';

class MockReservation {
  final int id;
  final String fieldName;
  final DateTime date;
  final String timeSlot;
  final String customerName;
  final int price;
  String status;

  MockReservation({
    required this.id,
    required this.fieldName,
    required this.date,
    required this.timeSlot,
    required this.customerName,
    required this.price,
    required this.status,
  });
}

class MockReservations {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static final List<MockReservation> reservations = [
    MockReservation(
      id: 1,
      fieldName: 'Arena Fudbal',
      date: DateTime.now().add(const Duration(days: 1)),
      timeSlot: '10:00 - 11:00',
      customerName: 'Marko Marković',
      price: 3000,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 2,
      fieldName: 'Basket Centar',
      date: DateTime.now().add(const Duration(days: 2)),
      timeSlot: '12:00 - 13:00',
      customerName: 'Nikola Petrović',
      price: 1500,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 3,
      fieldName: 'Tennis Club',
      date: DateTime.now().add(const Duration(days: 3)),
      timeSlot: '09:00 - 10:00',
      customerName: 'Ana Jovanović',
      price: 2000,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 4,
      fieldName: 'Padel Arena',
      date: DateTime.now().add(const Duration(days: 4)),
      timeSlot: '16:00 - 17:00',
      customerName: 'Stefan Ilić',
      price: 2500,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 5,
      fieldName: 'Sport Zone',
      date: DateTime.now().add(const Duration(days: 5)),
      timeSlot: '18:00 - 19:00',
      customerName: 'Luka Đorđević',
      price: 3500,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 6,
      fieldName: 'Olimpijski Bazen',
      date: DateTime.now().subtract(const Duration(days: 1)),
      timeSlot: '11:00 - 12:00',
      customerName: 'Milica Nikolić',
      price: 1200,
      status: 'Završena',
    ),
    MockReservation(
      id: 7,
      fieldName: 'Volley Arena',
      date: DateTime.now().subtract(const Duration(days: 2)),
      timeSlot: '14:00 - 15:00',
      customerName: 'Jovana Stojanović',
      price: 1800,
      status: 'Završena',
    ),
    MockReservation(
      id: 8,
      fieldName: 'Futsal Centar',
      date: DateTime.now().subtract(const Duration(days: 3)),
      timeSlot: '19:00 - 20:00',
      customerName: 'Petar Simić',
      price: 2800,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 9,
      fieldName: 'Tenis Akademija',
      date: DateTime.now().subtract(const Duration(days: 4)),
      timeSlot: '08:00 - 09:00',
      customerName: 'Sara Pavlović',
      price: 2200,
      status: 'Završena',
    ),
    MockReservation(
      id: 10,
      fieldName: 'Basket 3x3',
      date: DateTime.now().subtract(const Duration(days: 5)),
      timeSlot: '15:00 - 16:00',
      customerName: 'Filip Milošević',
      price: 1000,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 11,
      fieldName: 'Arena Fudbal',
      date: DateTime.now().add(const Duration(days: 6)),
      timeSlot: '17:00 - 18:00',
      customerName: 'Aleksandar Popović',
      price: 3000,
      status: 'Potvrđena',
    ),
    MockReservation(
      id: 12,
      fieldName: 'Basket Centar',
      date: DateTime.now().add(const Duration(days: 7)),
      timeSlot: '13:00 - 14:00',
      customerName: 'Teodora Kostić',
      price: 1500,
      status: 'Na čekanju',
    ),
    MockReservation(
      id: 13,
      fieldName: 'Tennis Club',
      date: DateTime.now().subtract(const Duration(days: 6)),
      timeSlot: '10:00 - 11:00',
      customerName: 'Miloš Ristić',
      price: 2000,
      status: 'Otkazana',
    ),
    MockReservation(
      id: 14,
      fieldName: 'Padel Arena',
      date: DateTime.now().subtract(const Duration(days: 7)),
      timeSlot: '12:00 - 13:00',
      customerName: 'Katarina Lazić',
      price: 2500,
      status: 'Završena',
    ),
    MockReservation(
      id: 15,
      fieldName: 'Sport Zone',
      date: DateTime.now().add(const Duration(days: 8)),
      timeSlot: '09:00 - 10:00',
      customerName: 'Nemanja Vasić',
      price: 3500,
      status: 'Potvrđena',
    ),
  ];

  static int _nextId = 16;

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
        fieldName: fieldName,
        date: date,
        timeSlot: timeSlot,
        customerName: customerName,
        price: price,
        status: 'Na čekanju',
      ),
    );

    changes.value++;
  }

  static void cancel(int reservationId) {
    final index = reservations.indexWhere(
          (reservation) => reservation.id == reservationId,
    );

    if (index == -1) {
      return;
    }

    final reservation = reservations[index];

    // Zavrsene i vec otkazane rezervacije ne menjamo.
    if (reservation.status == 'Završena' ||
        reservation.status == 'Otkazana') {
      return;
    }

    reservation.status = 'Otkazana';
    changes.value++;
  }
}
