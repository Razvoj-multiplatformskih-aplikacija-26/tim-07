import 'package:flutter/material.dart';

import '../screens/placeholder_page.dart';
import '../screens/reservations_page.dart';

class BackofficeShell extends StatefulWidget {
  const BackofficeShell({super.key});

  @override
  State<BackofficeShell> createState() => _BackofficeShellState();
}

class _BackofficeShellState extends State<BackofficeShell> {
  int _selectedIndex = 0;

  static const _sections = <_Section>[
    _Section(
      label: 'Rezervacije',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
    ),
    _Section(
      label: 'Tereni',
      icon: Icons.stadium_outlined,
      selectedIcon: Icons.stadium,
    ),
    _Section(
      label: 'Statistika',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
  ];

  Widget _buildPage(int index) {
    return switch (index) {
      0 => const ReservationsPage(),
      1 => const PlaceholderPage(
          title: 'Tereni',
          message: 'Upravljanje terenima biće dodato u narednim taskovima.',
        ),
      _ => const PlaceholderPage(
          title: 'Statistika',
          message: 'Statistika zauzetosti biće dodata u narednim taskovima.',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Icon(
                Icons.sports_soccer,
                size: 32,
                color: colors.primary,
              ),
            ),
            destinations: [
              for (final section in _sections)
                NavigationRailDestination(
                  icon: Icon(section.icon),
                  selectedIcon: Icon(section.selectedIcon),
                  label: Text(section.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                _Header(title: _sections[_selectedIndex].label),
                const Divider(height: 1),
                Expanded(child: _buildPage(_selectedIndex)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _Section({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const Spacer(),
            Text(
              'Terenzo backoffice',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
