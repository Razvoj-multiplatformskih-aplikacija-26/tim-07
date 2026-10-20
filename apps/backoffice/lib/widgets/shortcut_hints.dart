import 'package:flutter/material.dart';

class ShortcutHints extends StatelessWidget {
  const ShortcutHints({super.key});

  static const hints = <(String, String)>[
    ('↑ ↓', 'kretanje'),
    ('Home / End', 'prva / poslednja'),
    ('Enter', 'akcije'),
    ('P', 'potvrdi'),
    ('O', 'odbij / otkaži'),
    ('R', 'osveži'),
    ('Esc', 'nazad / poništi izbor'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surfaceContainerLow,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          for (final (key, label) in hints)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(key, style: theme.textTheme.labelSmall),
                ),
                const SizedBox(width: 6),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}
