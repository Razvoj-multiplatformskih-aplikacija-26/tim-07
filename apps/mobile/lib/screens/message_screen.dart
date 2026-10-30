import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Ekran za adresu koja ne pokazuje ni na jedan zapis.
class MessageScreen extends StatelessWidget {
  final String title;
  final String message;

  const MessageScreen({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/'),
                child: const Text('Na početnu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
