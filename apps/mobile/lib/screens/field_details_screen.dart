
import 'package:flutter/material.dart';

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
  State<FieldDetailsScreen> createState() => _FieldDetailsScreenState();
}

class _FieldDetailsScreenState extends State<FieldDetailsScreen> {
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

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

  // Proverava da li je termin slobodan.
  // Privremena simulacija na osnovu terena i datuma.
  bool isSlotAvailable(int index) {
    final fieldCode = widget.name.runes.fold<int>(
      0,
          (sum, character) => sum + character,
    );

    final dateCode = selectedDate.year * 10000 +
        selectedDate.month * 100 +
        selectedDate.day;

    return (fieldCode + dateCode + index * 7) % 5 != 0;
  }

  // Prikazuje sve termine za izabrani datum.
  Widget buildTimeSlots() {
    final times = [
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

    return Column(
      children: List.generate(times.length, (index) {
        final available = isSlotAvailable(index);

        return Card(
          child: ListTile(
            leading: Icon(
              available ? Icons.check_circle : Icons.cancel,
              color: available ? Colors.green : Colors.red,
            ),
            title: Text(times[index]),
            subtitle: Text(
              available ? 'Slobodan termin' : 'Zauzet termin',
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

    // Formatiranje datuma: DD.MM.YYYY.
    final formattedDate =
        '${selectedDate.day.toString().padLeft(2, '0')}.'
        '${selectedDate.month.toString().padLeft(2, '0')}.'
        '${selectedDate.year}.';

    // Broj slobodnih termina za izabrani datum.
    final availableCount = List.generate(
      12,
          (index) => isSlotAvailable(index),
    ).where((available) => available).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalji terena'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Slika / ikonica terena
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

          // Naziv terena
          Text(
            widget.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),

          const SizedBox(height: 16),

          // Lokacija
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

          // Sport
          Row(
            children: [
              const Icon(Icons.sports),
              const SizedBox(width: 8),
              Text(widget.sport),
            ],
          ),

          const SizedBox(height: 12),

          // Cena
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

          // Opis terena
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

          // Dostupni termini
          Text(
            'Dostupni termini',
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 12),

          // Dugme za izbor datuma
          OutlinedButton.icon(
            onPressed: selectDate,
            icon: const Icon(Icons.calendar_month),
            label: Text('Datum: $formattedDate'),
          ),

          const SizedBox(height: 12),

          // Brojač slobodnih termina
          Text(
            'Slobodnih termina: $availableCount od 12',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 12),

          // Lista termina
          buildTimeSlots(),
        ],
      ),
    );
  }
}
