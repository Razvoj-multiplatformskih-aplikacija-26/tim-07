import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/blocked_periods_page.dart';
import '../screens/calendar_page.dart';
import '../screens/fields_page.dart';
import '../screens/field_review_page.dart';
import '../screens/statistics_page.dart';
import '../screens/reservations_page.dart';
import '../screens/users_page.dart';
import '../widgets/simulation_menu.dart';

class BackofficeShell extends StatefulWidget {
  const BackofficeShell({super.key});

  @override
  State<BackofficeShell> createState() => _BackofficeShellState();
}

class _BackofficeShellState extends State<BackofficeShell> {
  int _selectedIndex = 0;

  static const _common = <_Section>[
    _Section(
      label: 'Rezervacije',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      page: ReservationsPage(),
    ),
    _Section(
      label: 'Kalendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      page: CalendarPage(),
    ),
    _Section(
      label: 'Tereni',
      icon: Icons.stadium_outlined,
      selectedIcon: Icons.stadium,
      page: FieldsPage(),
    ),
    _Section(
      label: 'Blokade',
      icon: Icons.event_busy_outlined,
      selectedIcon: Icons.event_busy,
      page: BlockedPeriodsPage(),
    ),
    _Section(
      label: 'Statistika',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      page: StatisticsPage(),
    ),
  ];

  static const _review = _Section(
    label: 'Odobravanje',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    page: FieldReviewPage(),
  );

  static const _users = _Section(
    label: 'Korisnici',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    page: UsersPage(),
  );

  List<_Section> _sectionsFor(AppUser user) => [
    ..._common,
    if (canReviewField(user)) _review,
    if (canManageUsers(user)) _users,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sections = _sectionsFor(context.read<AppUser>());
    final selected = _selectedIndex < sections.length ? _selectedIndex : 0;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
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
              for (final section in sections)
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
                  title: sections[selected].label,
                  showSimulation: selected == 0,
                ),
                const Divider(height: 1),
                Expanded(child: sections[selected].page),
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
  final Widget page;

  const _Section({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
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
