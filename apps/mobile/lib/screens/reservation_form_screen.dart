
import 'package:flutter/material.dart';
import 'package:domain/domain.dart';

import '../data/mock_reservations.dart';

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

  static const String _currentUserName = 'Marko Marković';

  final _nameController = TextEditingController(
    text: _currentUserName,
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  DateTime _parseTime(String time) {
    final parts = time.trim().split(':');

    return DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void confirmReservation() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final times = widget.timeSlot.split('-');

    final startTime = _parseTime(times[0]);
    final endTime = _parseTime(times[1]);

    // Koristimo domensko pravilo za validaciju termina.
    final validationError = validateReservationTime(
      startTime: startTime,
      endTime: endTime,
      now: DateTime.now(),
    );

    if (validationError != null) {
      _showMessage(validationError.message);
      return;
    }

    // Privremena provera zauzetosti dok ne povezemo Bloc.
    final alreadyReserved = MockReservations.reservations.any(
          (reservation) =>
      reservation.fieldName == widget.fieldName &&
          DateUtils.isSameDay(reservation.date, widget.date) &&
          reservation.timeSlot == widget.timeSlot &&
          reservation.status != 'Otkazana',
    );

    if (alreadyReserved) {
      _showMessage('Ovaj termin je već rezervisan.');
      return;
    }

    MockReservations.add(
      fieldName: widget.fieldName,
      date: widget.date,
      timeSlot: widget.timeSlot,
      customerName: _currentUserName,
      price: widget.price,
    );

    _showMessage('Rezervacija je uspešno kreirana!');

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
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Ime i prezime',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                helperText: 'Prijavljeni demo korisnik',
              ),
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
