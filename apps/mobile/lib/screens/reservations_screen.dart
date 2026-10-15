
import 'package:flutter/material.dart';
import '../data/mock_reservations.dart';

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() =>
      _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  // Prati promene u mock rezervacijama.
  @override
  void initState() {
    super.initState();
    MockReservations.changes.addListener(refreshReservations);
  }

  // Automatski osvezava ekran kada se rezervacije promene.
  void refreshReservations() {
    if (mounted) {
      setState(() {});
    }
  }

  // Uklanja listener kada se ekran unisti.
  @override
  void dispose() {
    MockReservations.changes.removeListener(refreshReservations);
    super.dispose();
  }

  // Otkazivanje rezervacije uz potvrdu korisnika.
  Future<void> cancelReservation(int reservationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Otkaži rezervaciju'),
        content: const Text(
          'Da li ste sigurni da želite da otkažete ovu rezervaciju?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ne'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Da, otkaži'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    // MockReservations.cancel() obavestava listener.
    MockReservations.cancel(reservationId);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rezervacija je otkazana.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservations = MockReservations.reservations;

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

          final formattedDate =
              '${reservation.date.day.toString().padLeft(2, '0')}.'
              '${reservation.date.month.toString().padLeft(2, '0')}.'
              '${reservation.date.year}.';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Naziv terena
                  Text(
                    reservation.fieldName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 12),

                  // Datum
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined),
                      const SizedBox(width: 8),
                      Text(formattedDate),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Vreme
                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      Text(reservation.timeSlot),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Ime korisnika
                  Row(
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(reservation.customerName),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Cena
                  Text(
                    '${reservation.price} RSD',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Status rezervacije
                  Chip(
                    avatar: Icon(
                      isCancelled
                          ? Icons.cancel_outlined
                          : Icons.schedule,
                      size: 18,
                    ),
                    label: Text(reservation.status),
                  ),

                  // Dugme samo za aktivne rezervacije
                  if (!isCancelled && reservation.status != 'Završena') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          cancelReservation(reservation.id),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Otkaži rezervaciju'),
                    ),
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
