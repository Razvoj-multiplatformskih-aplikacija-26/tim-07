import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/blocked_periods_page.dart';
import '../screens/calendar_page.dart';
import '../screens/placeholder_page.dart';
import '../screens/reservations_page.dart';
import '../widgets/simulation_menu.dart';

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
      label: 'Kalendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
    _Section(
      label: 'Tereni',
      icon: Icons.stadium_outlined,
      selectedIcon: Icons.stadium,
    ),
    _Section(
      label: 'Blokade',
      icon: Icons.event_busy_outlined,
      selectedIcon: Icons.event_busy,
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
      1 => const CalendarPage(),
      2 => const PlaceholderPage(
          title: 'Tereni',
          message: 'Upravljanje terenima biće dodato u narednim taskovima.',
        ),
      3 => const BlockedPeriodsPage(),
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
            trailing: const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(padding: EdgeInsets.only(bottom: 16), child: _Account()),
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
                _Header(
                  title: _sections[_selectedIndex].label,
                  showSimulation: _selectedIndex == 0,
                ),
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
  final bool showSimulation;

  const _Header({required this.title, required this.showSimulation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showAppName = constraints.maxWidth >= 600;

            return Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (showAppName)
                  Text(
                    'Terenzo backoffice',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (showSimulation) ...[
                  const SizedBox(width: 8),
                  const SimulationMenu(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account();

  @override
  Widget build(BuildContext context) {
    final AuthBloc auth;
    try {
      auth = BlocProvider.of<AuthBloc>(context);
    } on Object {
      return const SizedBox.shrink();
    }
    final user = auth.state.user;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user != null)
          SizedBox(
            width: 88,
            child: Text(
              user.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        IconButton(
          tooltip: 'Odjavi se',
          icon: const Icon(Icons.logout),
          onPressed: () => auth.add(const AuthLogoutRequested()),
        ),
      ],
    );
  }
}
