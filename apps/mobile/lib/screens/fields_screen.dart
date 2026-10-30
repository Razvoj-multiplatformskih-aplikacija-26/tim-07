import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/mobile_demo_data.dart';
import '../text/reservation_texts.dart';
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

  final sports = [
    'Svi',
    'Fudbal',
    'Košarka',
    'Tenis',
    'Padel',
    'Plivanje',
    'Odbojka',
    'Futsal',
  ];

  final fields = MobileDemoData.fields;

  @override
  Widget build(BuildContext context) {
    final filteredFields = fields.where((field) {
      final matchesSearch = field.name.toLowerCase().contains(
        searchQuery.trim().toLowerCase(),
      );

      final matchesSport =
          selectedSport == 'Svi' || sportLabel(field.sport) == selectedSport;

      return matchesSearch && matchesSport;
    }).toList();
    if (selectedSort == 'Cena: od najniže') {
      filteredFields.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
    } else if (selectedSort == 'Cena: od najviše') {
      filteredFields.sort((a, b) => b.pricePerHour.compareTo(a.pricePerHour));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sportski tereni')),
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
              separatorBuilder: (context, index) => const SizedBox(width: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pronađeno terena: ${filteredFields.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
                ? const Center(child: Text('Nema pronađenih terena.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredFields.length,
                    itemBuilder: (context, index) {
                      final field = filteredFields[index];

                      return FieldCard(
                        name: field.name,
                        location: field.address,
                        sport: sportLabel(field.sport),
                        pricePerHour: field.pricePerHour,
                        onTap: () => context.push('/fields/${field.id.value}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
