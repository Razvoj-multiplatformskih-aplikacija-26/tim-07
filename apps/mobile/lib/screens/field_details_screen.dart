import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../text/field_texts.dart';
import '../text/reservation_texts.dart';
import '../widgets/sport_icon.dart';

/// Detalj terena sa slobodnim terminima za izabrani dan.
///
/// Termine ne pravi ekran: dolaze iz `AvailabilityBloc`-a (radno vreme terena,
/// rezervacije i blokade). Ekran samo šalje događaje i crta stanje.
class FieldDetailsScreen extends StatelessWidget {
  final SportsField field;

  const FieldDetailsScreen({super.key, required this.field});

  Future<void> _selectDate(BuildContext context, DateTime current) async {
    final bloc = context.read<AvailabilityBloc>();
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (picked != null) bloc.add(AvailabilityDaySelected(picked));
  }

  Future<void> _openReservation(
    BuildContext context,
    DateTime day,
    AvailabilitySlot slot,
  ) async {
    final bloc = context.read<AvailabilityBloc>();

    await context.push(
      Uri(
        path: '/fields/${field.id.value}/reserve',
        queryParameters: {
          'date': DateUtils.dateOnly(day).toIso8601String(),
          'start': formatClock(slot.startTime),
          'end': formatClock(slot.endTime),
        },
      ).toString(),
    );

    // Termin je mogao da bude zauzet dok je korisnik bio na formi.
    bloc.add(const AvailabilityRequested());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalji terena')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.stadium, size: 80, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(field.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(field.address)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(sportIcon(field.sport)),
              const SizedBox(width: 8),
              Text(sportLabel(field.sport)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 8),
              Text(
                '${field.pricePerHour} RSD / sat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('O terenu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(field.description),
          const SizedBox(height: 24),
          Text(
            'Dostupni termini',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          BlocBuilder<AvailabilityBloc, AvailabilityState>(
            builder: (context, state) => _Availability(
              state: state,
              onSelectDate: () => _selectDate(context, state.day),
              onRetry: () => context.read<AvailabilityBloc>().add(
                const AvailabilityRequested(),
              ),
              onOpen: (slot) => _openReservation(context, state.day, slot),
            ),
          ),
        ],
      ),
    );
  }
}

class _Availability extends StatelessWidget {
  final AvailabilityState state;
  final VoidCallback onSelectDate;
  final VoidCallback onRetry;
  final void Function(AvailabilitySlot slot) onOpen;

  const _Availability({
    required this.state,
    required this.onSelectDate,
    required this.onRetry,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dan se bira i dok se termini učitavaju ili je došlo do greške.
        OutlinedButton.icon(
          onPressed: onSelectDate,
          icon: const Icon(Icons.calendar_month),
          label: Text('Datum: ${formatDate(state.day)}'),
        ),
        const SizedBox(height: 12),
        switch (state) {
          AvailabilityLoading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          AvailabilityError(:final message) => Column(
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
          AvailabilityEmpty() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Teren ne radi izabranog dana.',
              textAlign: TextAlign.center,
            ),
          ),
          final AvailabilityLoaded loaded => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Slobodnih termina: ${loaded.freeCount} od ${loaded.slots.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              for (final slot in loaded.slots)
                _SlotTile(slot: slot, onTap: () => onOpen(slot)),
            ],
          ),
        },
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  final AvailabilitySlot slot;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final free = slot.isFree;

    return Card(
      child: ListTile(
        onTap: free ? onTap : null,
        leading: Icon(
          free ? Icons.check_circle : Icons.cancel,
          color: free ? Colors.green : Colors.red,
        ),
        title: Text(formatTimeRange(slot.startTime, slot.endTime)),
        subtitle: Text(slotStateLabel(slot.state)),
        trailing: free
            ? const Icon(Icons.chevron_right)
            : const Icon(Icons.lock_outline),
      ),
    );
  }
}
