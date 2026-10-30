import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';

class ReservationFormScreen extends StatefulWidget {
  final SportsField field;
  final DateTime date;
  final String initialStart;
  final String initialEnd;

  const ReservationFormScreen({
    super.key,
    required this.field,
    required this.date,
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<ReservationFormScreen> createState() => _ReservationFormScreenState();
}

class _ReservationFormScreenState extends State<ReservationFormScreen> {
  static const _formatHint = 'Unesite vreme u obliku HH:mm, na primer 18:00.';

  final _formKey = GlobalKey<FormState>();

  late final _startController = TextEditingController(
    text: widget.initialStart,
  );
  late final _endController = TextEditingController(text: widget.initialEnd);
  final _nameController = TextEditingController(
    text: MobileDemoData.currentUserName,
  );

  bool _submitting = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  DateTime? _parseTime(String? text) {
    final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(text ?? '');
    if (match == null) {
      return null;
    }

    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      return null;
    }

    return DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      hour,
      minute,
    );
  }

  String? _formatError(String? text) =>
      _parseTime(text) == null ? _formatHint : null;

  // Pravila dolaze iz paketa domain; aplikacija samo bira tekst poruke.
  String? _slotError() {
    final start = _parseTime(_startController.text);
    final end = _parseTime(_endController.text);
    if (start == null || end == null) {
      return null;
    }

    final state = context.read<ReservationBloc>().state;
    final known = state is ReservationLoaded
        ? state.reservations
        : const <Reservation>[];

    final error = validateReservationSlot(
      fieldId: widget.field.id,
      userId: MobileDemoData.currentUserId,
      startTime: start,
      endTime: end,
      now: DateTime.now(),
      existingReservations: known,
      schedules: MobileDemoData.schedules,
    );

    return error == null ? null : validationMessage(error);
  }

  int? get _price {
    final start = _parseTime(_startController.text);
    final end = _parseTime(_endController.text);
    if (start == null || end == null) {
      return null;
    }

    return calculateReservationPrice(
      pricePerHour: widget.field.pricePerHour,
      startTime: start,
      endTime: end,
    );
  }

  void _onTimeChanged(String _) {
    _formKey.currentState?.validate();
    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void confirmReservation() {
    if (_submitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    context.read<ReservationBloc>().add(
      ReservationCreateRequested(
        fieldId: widget.field.id,
        userId: MobileDemoData.currentUserId,
        startTime: _parseTime(_startController.text)!,
        endTime: _parseTime(_endController.text)!,
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
    final price = _price;

    return BlocListener<ReservationBloc, ReservationState>(
      listener: _onReservationState,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nova rezervacija')),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        widget.field.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text('Datum: ${formatDate(widget.date)}'),
                      const SizedBox(height: 8),
                      Text(
                        'Cena: ${price == null ? '-' : formatPrice(price)}',
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
              Text('Termin', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startController,
                keyboardType: TextInputType.datetime,
                onChanged: _onTimeChanged,
                validator: _formatError,
                decoration: const InputDecoration(
                  labelText: 'Početak (HH:mm)',
                  prefixIcon: Icon(Icons.schedule),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endController,
                keyboardType: TextInputType.datetime,
                onChanged: _onTimeChanged,
                validator: (value) => _formatError(value) ?? _slotError(),
                decoration: const InputDecoration(
                  labelText: 'Kraj (HH:mm)',
                  prefixIcon: Icon(Icons.schedule),
                  border: OutlineInputBorder(),
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
