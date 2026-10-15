
import 'package:flutter/material.dart';
import '../widgets/field_card.dart';

class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  String searchQuery = '';
  String selectedSport = 'Svi';
  String selectedSort = 'Podrazumevano';

  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void resetFilters() {
    setState(() {
      searchQuery = '';
      selectedSport = 'Svi';
      selectedSort = 'Podrazumevano';
      searchController.clear();
    });
  }

  final sports = ['Svi', 'Fudbal', 'Košarka', 'Tenis', 'Padel'];

  final fields = [
    (
    name: 'Arena Fudbal',
    location: 'Novi Beograd',
    sport: 'Fudbal',
    price: 3500,
    ),
    (
    name: 'Basket Centar',
    location: 'Voždovac',
    sport: 'Košarka',
    price: 2000,
    ),
    (
    name: 'Tennis Club',
    location: 'Zemun',
    sport: 'Tenis',
    price: 2500,
    ),
    (
    name: 'Padel Arena',
    location: 'Dorćol',
    sport: 'Padel',
    price: 3000,
    ),
    (
    name: 'Sport Zone',
    location: 'Banovo brdo',
    sport: 'Fudbal',
    price: 4000,
    ),
    (
    name: 'Olimpijski Bazen',
    location: 'Vračar',
    sport: 'Plivanje',
    price: 1800,
    ),
    (
    name: 'Volley Arena',
    location: 'Zvezdara',
    sport: 'Odbojka',
    price: 2800,
    ),
    (
    name: 'Futsal Centar',
    location: 'Zemun',
    sport: 'Fudbal',
    price: 3200,
    ),
    (
    name: 'Tenis Akademija',
    location: 'Novi Beograd',
    sport: 'Tenis',
    price: 2200,
    ),
    (
    name: 'Basket 3x3',
    location: 'Karaburma',
    sport: 'Košarka',
    price: 1500,
    )
  ];

  @override
  Widget build(BuildContext context) {
    final filteredFields = fields.where((field) {
      final matchesSearch = field.name.toLowerCase().contains(
        searchQuery.trim().toLowerCase(),
      );

      final matchesSport =
          selectedSport == 'Svi' || field.sport == selectedSport;

      return matchesSearch && matchesSport;
    }).toList();
    if (selectedSort == 'Cena: od najniže') {
      filteredFields.sort((a, b) => a.price.compareTo(b.price));
    } else if (selectedSort == 'Cena: od najviše') {
      filteredFields.sort((a, b) => b.price.compareTo(a.price));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportski tereni'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Pretraži terene...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.sort),
                const SizedBox(width: 8),
                const Text('Sortiraj:'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedSort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Podrazumevano',
                        child: Text('Podrazumevano'),
                      ),
                      DropdownMenuItem(
                        value: 'Cena: od najniže',
                        child: Text('Cena: od najniže'),
                      ),
                      DropdownMenuItem(
                        value: 'Cena: od najviše',
                        child: Text('Cena: od najviše'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedSort = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sports.length,
              separatorBuilder: (context, index) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final sport = sports[index];

                return Center(
                  child: FilterChip(
                    label: Text(sport),
                    selected: selectedSport == sport,
                    onSelected: (selected) {
                      setState(() {
                        selectedSport = sport;
                      });
                    },
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pronađeno terena: ${filteredFields.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty ||
                    selectedSport != 'Svi' ||
                    selectedSort != 'Podrazumevano')
                  TextButton.icon(
                    onPressed: resetFilters,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resetuj'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredFields.isEmpty
                ? const Center(
              child: Text('Nema pronađenih terena.'),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredFields.length,
              itemBuilder: (context, index) {
                final field = filteredFields[index];

                return FieldCard(
                  name: field.name,
                  location: field.location,
                  sport: field.sport,
                  pricePerHour: field.price,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
