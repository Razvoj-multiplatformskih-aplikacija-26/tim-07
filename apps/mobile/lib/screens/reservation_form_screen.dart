import '../data/mock_reservations.dart';
import 'package:flutter/material.dart';

class ReservationFormScreen extends StatefulWidget {
  final String fieldName;
  final DateTime date;
  final String timeSlot;
  final int price;

  const ReservationFormScreen({
    super.key,
    required this.fieldName,
    required this.date,
    required this.timeSlot,
    required this.price,
  });

  @override
  State<ReservationFormScreen> createState() =>
      _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }


  void confirmReservation() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Provera da termin nije već rezervisan.
    final alreadyReserved = MockReservations.reservations.any(
          (reservation) =>
      reservation.fieldName == widget.fieldName &&
          DateUtils.isSameDay(reservation.date, widget.date) &&
          reservation.timeSlot == widget.timeSlot &&
          reservation.status != 'Otkazana',
    );

    if (alreadyReserved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ovaj termin je već rezervisan.'),
        ),
      );
      return;
    }

    // Čuvanje rezervacije u memoriji.
    MockReservations.add(
      fieldName: widget.fieldName,
      date: widget.date,
      timeSlot: widget.timeSlot,
      customerName: _nameController.text.trim(),
      price: widget.price,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rezervacija je uspešno kreirana!'),
      ),
    );

    // Povratak na detalje terena.
    Navigator.of(context).pop();
  }


  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${widget.date.day.toString().padLeft(2, '0')}.'
        '${widget.date.month.toString().padLeft(2, '0')}.'
        '${widget.date.year}.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova rezervacija'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Detalji rezervacije',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.fieldName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 12),

                    Text('Datum: $formattedDate'),

                    const SizedBox(height: 8),

                    Text('Termin: ${widget.timeSlot}'),

                    const SizedBox(height: 8),

                    Text(
                      'Cena: ${widget.price} RSD',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Podaci za rezervaciju',
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ime i prezime',
                hintText: 'Unesite ime i prezime',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ime i prezime su obavezni.';
                }

                if (value.trim().length < 3) {
                  return 'Unesite najmanje 3 karaktera.';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: confirmReservation,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Potvrdi rezervaciju'),
            ),
          ],
        ),
      ),
    );
  }
}
