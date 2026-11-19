import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../text/reservation_texts.dart';
import 'sport_icon.dart';

class FieldCard extends StatelessWidget {
  final String name;
  final String location;
  final SportType sport;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = sportIcon(sport);

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
                  Icon(icon, size: 28, color: colorScheme.primary),
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
                avatar: Icon(icon, size: 18, color: colorScheme.primary),
                label: Text(sportLabel(sport)),
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
