
import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

import '../data/mock_reservations.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() =>
      _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  @override
  void initState() {
    super.initState();
    MockReservations.changes.addListener(refreshReservations);
  }

  void refreshReservations() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    MockReservations.changes.removeListener(refreshReservations);
    super.dispose();
  }

  // Pretvara tekst termina, npr. "10:00 - 11:00",
  // u pocetak i kraj rezervacije.
  DateTime _parseTime(
      DateTime date,
      String time,
      ) {
    final parts = time.trim().split(':');

    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  // Mapiranje statusa iz mock podataka u domenski enum.
  ReservationStatus _domainStatus(String status) {
    switch (status) {
      case 'Na čekanju':
        return ReservationStatus.pending;

      case 'Potvrđena':
        return ReservationStatus.confirmed;

      case 'Završena':
        return ReservationStatus.completed;

      case 'Otkazana':
        return ReservationStatus.cancelled;

      default:
        return ReservationStatus.cancelled;
    }
  }

  // Pravimo domenski model kako bismo koristili
  // zajednicko pravilo validateCancellation.
  Reservation _toDomainReservation(
      MockReservation mock,
      ) {
    final times = mock.timeSlot.split('-');

    final startTime = _parseTime(
      mock.date,
      times[0],
    );

    final endTime = _parseTime(
      mock.date,
      times[1],
    );

    return Reservation(
      id: ReservationId(mock.id),
      fieldId: FieldId(1),
      userId: mock.userId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: mock.price,
      status: _domainStatus(mock.status),
      createdAt: mock.date.subtract(
        const Duration(days: 1),
      ),
    );
  }

  // Ne ponavljamo pravilo od 5 sati u UI-ju.
  // Koristimo pravilo iz packages/domain.
  ReservationValidationError? _cancellationError(
      MockReservation mock,
      ) {
    final reservation = _toDomainReservation(mock);

    return validateCancellation(
      reservation: reservation,
      now: DateTime.now(),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> cancelReservation(
      MockReservation mock,
      ) async {
    // Provera pre prikazivanja dijaloga.
    final initialError = _cancellationError(mock);

    if (initialError != null) {
      _showMessage(initialError.message);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Otkaži rezervaciju'),
        content: const Text(
          'Da li ste sigurni da želite da otkažete '
              'ovu rezervaciju?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Da, otkaži'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    // Ponovna provera nakon dijaloga.
    // Rok je mogao da istekne dok je dijalog otvoren.
    final error = _cancellationError(mock);

    if (error != null) {
      _showMessage(error.message);
      return;
    }

    MockReservations.cancel(mock.id);

    if (mock.status == 'Otkazana') {
      _showMessage('Rezervacija je otkazana.');
    } else {
      _showMessage('Rezervacija nije mogla biti otkazana.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prikazujemo samo rezervacije demo korisnika.
    final reservations = MockReservations.myReservations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje rezervacije'),
      ),
      body: reservations.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 72,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Nemate rezervacija',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 8),
            Text(
              'Izaberite teren i rezervišite termin.',
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservations.length,
        itemBuilder: (context, index) {
          final reservation = reservations[index];

          final isCancelled =
              reservation.status == 'Otkazana';

          final isCompleted =
              reservation.status == 'Završena';

          final cancellationError =
          _cancellationError(reservation);

          final canCancel =
              cancellationError == null;

          final formattedDate =
              '${reservation.date.day.toString().padLeft(2, '0')}.'
              '${reservation.date.month.toString().padLeft(2, '0')}.'
              '${reservation.date.year}.';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.fieldName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge,
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                      ),
                      const SizedBox(width: 8),
                      Text(formattedDate),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(reservation.timeSlot),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reservation.customerName,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    '${reservation.price} RSD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Chip(
                    avatar: Icon(
                      isCancelled
                          ? Icons.cancel_outlined
                          : isCompleted
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                      size: 18,
                    ),
                    label: Text(reservation.status),
                  ),

                  if (!isCancelled &&
                      !isCompleted) ...[
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: canCancel
                          ? () => cancelReservation(
                        reservation,
                      )
                          : null,
                      icon: const Icon(
                        Icons.cancel_outlined,
                      ),
                      label: const Text(
                        'Otkaži rezervaciju',
                      ),
                    ),

                    if (!canCancel) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Otkazivanje je moguće '
                            'najkasnije 5 sati pre '
                            'početka termina.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
