
import 'package:flutter/material.dart';

class FieldCard extends StatelessWidget {
  final String name;
  final String location;
  final String sport;
  final int pricePerHour;
  final VoidCallback? onTap;

  const FieldCard({
    super.key,
    required this.name,
    required this.location,
    required this.sport,
    required this.pricePerHour,
    this.onTap,
  });


  IconData get sportIcon {
    switch (sport) {
      case 'Fudbal':
        return Icons.sports_soccer;
      case 'Košarka':
        return Icons.sports_basketball;
      case 'Tenis':
        return Icons.sports_tennis;
      case 'Padel':
        return Icons.sports_tennis;
      case 'Plivanje':
        return Icons.pool;
      case 'Odbojka':
        return Icons.sports_volleyball;
      default:
        return Icons.sports;
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    sportIcon,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(location)),
                ],
              ),
              const SizedBox(height: 8),
              Chip(
                avatar: Icon(
                  sportIcon,
                  size: 18,
                  color: colorScheme.primary,
                ),
                label: Text(sport),
                backgroundColor: colorScheme.primaryContainer,
                side: BorderSide.none,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$pricePerHour RSD / sat',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
