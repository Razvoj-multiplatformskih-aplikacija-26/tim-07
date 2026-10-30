import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';

class FieldDetailsScreen extends StatefulWidget {
  final SportsField field;

  const FieldDetailsScreen({super.key, required this.field});

  @override
  State<FieldDetailsScreen> createState() => _FieldDetailsScreenState();
}

class _FieldDetailsScreenState extends State<FieldDetailsScreen> {
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  static const List<String> times = [
    '08:00 - 09:00',
    '09:00 - 10:00',
    '10:00 - 11:00',
    '11:00 - 12:00',
    '12:00 - 13:00',
    '13:00 - 14:00',
    '14:00 - 15:00',
    '15:00 - 16:00',
    '16:00 - 17:00',
    '17:00 - 18:00',
    '18:00 - 19:00',
    '19:00 - 20:00',
  ];

  Future<void> selectDate() async {
    final today = DateUtils.dateOnly(DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(today) ? today : selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  ({DateTime start, DateTime end}) slotTimes(String timeSlot) {
    final parts = timeSlot.split('-').map((part) => part.trim()).toList();

    DateTime at(String time) {
      final clock = time.split(':');
      return DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        int.parse(clock[0]),
        int.parse(clock[1]),
      );
    }

    return (start: at(parts[0]), end: at(parts[1]));
  }

  bool isSlotAvailable(int index, List<Reservation> reservations) {
    final slot = slotTimes(times[index]);

    final isFree =
        validateReservationTime(
              startTime: slot.start,
              endTime: slot.end,
              now: DateTime.now(),
            ) ==
            null &&
        !hasReservationOverlap(
          fieldId: widget.field.id,
          userId: MobileDemoData.currentUserId,
          startTime: slot.start,
          endTime: slot.end,
          existingReservations: reservations,
        );

    if (!isFree) {
      return false;
    }

    // Pocetna simulacija termina koje su zauzeli drugi korisnici.
    final fieldCode = widget.field.name.runes.fold<int>(
      0,
      (sum, character) => sum + character,
    );

    final dateCode =
        selectedDate.year * 10000 + selectedDate.month * 100 + selectedDate.day;

    return (fieldCode + dateCode + index * 7) % 5 != 0;
  }

  Future<void> openReservation(String timeSlot) async {
    final slot = slotTimes(timeSlot);

    await context.push(
      Uri(
        path: '/fields/${widget.field.id.value}/reserve',
        queryParameters: {
          'date': DateUtils.dateOnly(selectedDate).toIso8601String(),
          'start': formatClock(slot.start),
          'end': formatClock(slot.end),
        },
      ).toString(),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Widget buildTimeSlots(List<Reservation> reservations) {
    return Column(
      children: List.generate(times.length, (index) {
        final available = isSlotAvailable(index, reservations);
        final timeSlot = times[index];

        return Card(
          child: ListTile(
            onTap: available ? () => openReservation(timeSlot) : null,
            leading: Icon(
              available ? Icons.check_circle : Icons.cancel,
              color: available ? Colors.green : Colors.red,
            ),
            title: Text(timeSlot),
            subtitle: Text(available ? 'Slobodan termin' : 'Zauzet termin'),
            trailing: available
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.lock_outline),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<ReservationBloc>().state;
    final reservations = state is ReservationLoaded
        ? state.reservations
        : const <Reservation>[];

    final formattedDate =
        '${selectedDate.day.toString().padLeft(2, '0')}.'
        '${selectedDate.month.toString().padLeft(2, '0')}.'
        '${selectedDate.year}.';

    final availableCount = List.generate(
      times.length,
      (index) => isSlotAvailable(index, reservations),
    ).where((available) => available).length;

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

          Text(
            widget.field.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.field.address)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.sports),
              const SizedBox(width: 8),
              Text(sportLabel(widget.field.sport)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 8),
              Text(
                '${widget.field.pricePerHour} RSD / sat',
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

          Text(widget.field.description),

          const SizedBox(height: 24),

          Text(
            'Dostupni termini',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: selectDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Datum: $formattedDate'),
          ),

          const SizedBox(height: 12),

          Text(
            'Slobodnih termina: $availableCount od ${times.length}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 12),

          buildTimeSlots(reservations),
        ],
      ),
    );
  }
}
