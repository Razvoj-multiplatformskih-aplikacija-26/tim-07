
import 'package:flutter/material.dart';
import '../widgets/field_card.dart';

class FieldsScreen extends StatelessWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportski tereni'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: fields.length,
        itemBuilder: (context, index) {
          final field = fields[index];

          return FieldCard(
            name: field.name,
            location: field.location,
            sport: field.sport,
            pricePerHour: field.price,
          );
        },
      ),
    );
  }
}
