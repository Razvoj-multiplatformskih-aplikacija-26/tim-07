
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';

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

  final _nameController = TextEditingController(
    text: MobileDemoData.currentUserName,
  );

  bool _submitting = false;

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
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    final fieldId = MobileDemoData.fieldIdByName(widget.fieldName);
    if (fieldId == null) {
      _showMessage('Teren nije pronađen.');
      return;
    }

    final times = widget.timeSlot.split('-');
    final startTime = _parseTime(times[0]);
    final endTime = _parseTime(times[1]);

    final validationError = validateReservationTime(
      startTime: startTime,
      endTime: endTime,
      now: DateTime.now(),
    );

    if (validationError != null) {
      _showMessage(validationMessage(validationError));
      return;
    }

    setState(() => _submitting = true);

    context.read<ReservationBloc>().add(
          ReservationCreateRequested(
            fieldId: fieldId,
            userId: MobileDemoData.currentUserId,
            startTime: startTime,
            endTime: endTime,
          ),
        );
  }

  void _onReservationState(BuildContext context, ReservationState state) {
    if (!_submitting) {
      return;
    }

    switch (state) {
      case ReservationLoaded() || ReservationEmpty():
        setState(() => _submitting = false);
        _showMessage('Rezervacija je uspešno kreirana!');
        Navigator.of(context).pop();
      case ReservationError(:final message):
        setState(() => _submitting = false);
        _showMessage(errorDetails(message));
      case ReservationInitial() || ReservationLoading():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        '${widget.date.day.toString().padLeft(2, '0')}.'
        '${widget.date.month.toString().padLeft(2, '0')}.'
        '${widget.date.year}.';

    return BlocListener<ReservationBloc, ReservationState>(
      listener: _onReservationState,
      child: Scaffold(
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
              onPressed: _submitting ? null : confirmReservation,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _submitting ? 'Slanje rezervacije...' : 'Potvrdi rezervaciju',
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
