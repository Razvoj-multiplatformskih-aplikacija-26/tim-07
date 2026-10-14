
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportski tereni'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            const Text(
              'Dobrodošli!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Pronađite i rezervišite sportski teren.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.go('/fields');
              },
              icon: const Icon(Icons.search),
              label: const Text('Pregledaj terene'),
            ),
          ],
        ),
      ),
    );
  }
}
