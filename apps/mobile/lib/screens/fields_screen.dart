
import 'package:flutter/material.dart';

class FieldsScreen extends StatelessWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportski tereni'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports,
              size: 80,
            ),
            SizedBox(height: 20),
            Text(
              'Pregled sportskih terena',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Ovde će biti prikazani dostupni tereni.',
            ),
          ],
        ),
      ),
    );
  }
}
