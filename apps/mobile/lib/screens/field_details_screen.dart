
import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../data/mobile_demo_data.dart';

class FieldDetailsScreen extends StatefulWidget {
  final String name;
  final String location;
  final String sport;
  final int pricePerHour;

  const FieldDetailsScreen({
    super.key,
    required this.name,
    required this.location,
    required this.sport,
    required this.pricePerHour,
  });

  @override
  State<FieldDetailsScreen> createState() =>
      _FieldDetailsScreenState();
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
      initialDate: selectedDate.isBefore(today)
          ? today
          : selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );

    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  bool isSlotAvailable(int index, List<Reservation> reservations) {
    final fieldId = MobileDemoData.fieldIdByName(widget.name);
    final startHour = int.parse(times[index].substring(0, 2));

    final alreadyReserved = reservations.any(
      (reservation) =>
          reservation.isActive &&
          reservation.fieldId == fieldId &&
          DateUtils.isSameDay(reservation.startTime, selectedDate) &&
          reservation.startTime.hour == startHour,
    );

    if (alreadyReserved) {
      return false;
    }

    // Pocetna simulacija zauzetih termina.
    final fieldCode = widget.name.runes.fold<int>(
      0,
          (sum, character) => sum + character,
    );

    final dateCode =
        selectedDate.year * 10000 +
            selectedDate.month * 100 +
            selectedDate.day;

    return (fieldCode + dateCode + index * 7) % 5 != 0;
  }

  Future<void> openReservation(String timeSlot) async {
    await context.push(
      '/fields/reserve',
      extra: (
      fieldName: widget.name,
      date: selectedDate,
      timeSlot: timeSlot,
      price: widget.pricePerHour,
      ),
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
            onTap: available
                ? () => openReservation(timeSlot)
                : null,
            leading: Icon(
              available
                  ? Icons.check_circle
                  : Icons.cancel,
              color: available
                  ? Colors.green
                  : Colors.red,
            ),
            title: Text(timeSlot),
            subtitle: Text(
              available
                  ? 'Slobodan termin'
                  : 'Zauzet termin',
            ),
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
      appBar: AppBar(
        title: const Text('Detalji terena'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.stadium,
              size: 80,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            widget.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.location_on_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.location),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.sports),
              const SizedBox(width: 8),
              Text(widget.sport),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 8),
              Text(
                '${widget.pricePerHour} RSD / sat',
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

          Text(
            'O terenu',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          const Text(
            'Sportski teren dostupan za rekreativne aktivnosti '
                'i organizovane termine. '
                'Izaberite odgovarajući termin za svoju aktivnost.',
          ),

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
