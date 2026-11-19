import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/directory.dart';
import '../selection/reservation_selection_bloc.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';

/// Kolone kalendara: tereni (dnevni prikaz) ili dani jednog terena (nedeljni).
///
/// Širok prozor ih crta jednu pored druge (sa pomeranjem u stranu kada ih je
/// puno), uzak jednu ispod druge. Svaki red nosi tekst stanja, pa boja nije
/// jedini nosilac značenja.
class CalendarColumns extends StatelessWidget {
  final CalendarLoaded state;

  /// Vlasnik je izabrao rezervaciju.
  final ValueChanged<Reservation> onOpen;

  static const columnWidth = 220.0;

  const CalendarColumns({super.key, required this.state, required this.onOpen});

  String _title(BuildContext context, FieldCalendarDay day) {
    if (state.view == CalendarView.day) {
      return state.fields
          .firstWhere(
            (field) => field.id == day.fieldId,
            orElse: () => state.field,
          )
          .name;
    }
    return '${weekdayShort(day.date)} ${formatDayMonth(day.date)}';
  }

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final day in state.days)
        _Column(
          day: day,
          title: _title(context, day),
          now: state.now,
          onOpen: onOpen,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 2 * columnWidth) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final column in columns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: column,
                ),
            ],
          );
        }

        final width = ((constraints.maxWidth - 32) / columns.length).clamp(
          columnWidth,
          double.infinity,
        );

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final column in columns)
                    SizedBox(
                      width: width - 8,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: column,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  final FieldCalendarDay day;
  final String title;
  final DateTime now;
  final ValueChanged<Reservation> onOpen;

  const _Column({
    required this.day,
    required this.title,
    required this.now,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            if (!day.isOpen)
              const CalendarEntryTile(
                icon: Icons.do_not_disturb_on_outlined,
                title: 'Ne radi',
                subtitle: 'Teren tog dana nema radno vreme.',
                kind: CalendarTileKind.closed,
              )
            else
              for (final entry in day.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _EntryTile(entry: entry, onOpen: onOpen),
                ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final CalendarEntry entry;
  final ValueChanged<Reservation> onOpen;

  const _EntryTile({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final range = formatTimeRange(entry.startTime, entry.endTime);

    return switch (entry) {
      CalendarFreeSlot(:final isPast) => CalendarEntryTile(
        icon: isPast ? Icons.history : Icons.event_available_outlined,
        title: range,
        subtitle: isPast ? 'Prošlo' : 'Slobodno',
        kind: isPast ? CalendarTileKind.past : CalendarTileKind.free,
      ),
      CalendarBlock(:final period) => CalendarEntryTile(
        icon: Icons.block,
        title: range,
        subtitle: period.reason == null || period.reason!.isEmpty
            ? 'Blokirano'
            : 'Blokirano: ${period.reason}',
        kind: CalendarTileKind.blocked,
      ),
      CalendarReservation(:final reservation, :final status) =>
        _ReservationTile(
          reservation: reservation,
          status: status,
          range: range,
          onOpen: onOpen,
        ),
    };
  }
}

class _ReservationTile extends StatelessWidget {
  final Reservation reservation;
  final ReservationStatus status;
  final String range;
  final ValueChanged<Reservation> onOpen;

  const _ReservationTile({
    required this.reservation,
    required this.status,
    required this.range,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DirectoryCubit>().state;
    final selected =
        context.watch<ReservationSelectionBloc>().state.selectedId ==
        reservation.id;
    final label = ReservationStatusChip.label(status);

    return CalendarEntryTile(
      icon: switch (status) {
        ReservationStatus.pending => Icons.hourglass_top,
        ReservationStatus.completed => Icons.task_alt,
        _ => Icons.check_circle_outline,
      },
      title: range,
      subtitle: '$label: ${directory.customerName(reservation)}',
      kind: switch (status) {
        ReservationStatus.pending => CalendarTileKind.pending,
        ReservationStatus.completed => CalendarTileKind.completed,
        _ => CalendarTileKind.confirmed,
      },
      selected: selected,
      onTap: () => onOpen(reservation),
    );
  }
}

enum CalendarTileKind {
  free,
  past,
  pending,
  confirmed,
  completed,
  blocked,
  closed,
}

/// Jedan red kalendara: ikona, vreme i tekst stanja. Ako ima [onTap], može da
/// se izabere mišem i tastaturom (Tab, pa Enter ili razmak).
class CalendarEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final CalendarTileKind kind;
  final bool selected;
  final VoidCallback? onTap;

  const CalendarEntryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.kind,
    this.selected = false,
    this.onTap,
  });

  static ({Color background, Color foreground}) colors(
    CalendarTileKind kind,
    ColorScheme scheme,
  ) {
    return switch (kind) {
      CalendarTileKind.free => (
        background: scheme.surface,
        foreground: scheme.onSurface,
      ),
      CalendarTileKind.past || CalendarTileKind.closed => (
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      ),
      CalendarTileKind.pending => (
        background: scheme.tertiaryContainer,
        foreground: scheme.onTertiaryContainer,
      ),
      CalendarTileKind.confirmed => (
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      ),
      CalendarTileKind.completed => (
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      ),
      CalendarTileKind.blocked => (
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (:background, :foreground) = colors(kind, scheme);
    final interactive = onTap != null;

    return Semantics(
      container: true,
      button: interactive,
      selected: selected,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Objašnjenje boja i ikona iznad kalendara.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  static const _items = <(CalendarTileKind, IconData, String)>[
    (CalendarTileKind.free, Icons.event_available_outlined, 'Slobodno'),
    (CalendarTileKind.pending, Icons.hourglass_top, 'Na čekanju'),
    (CalendarTileKind.confirmed, Icons.check_circle_outline, 'Potvrđena'),
    (CalendarTileKind.completed, Icons.task_alt, 'Završena'),
    (CalendarTileKind.blocked, Icons.block, 'Blokirano'),
    (CalendarTileKind.past, Icons.history, 'Prošlo'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: 'Legenda kalendara',
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (kind, icon, label) in _items)
            Builder(
              builder: (context) {
                final (:background, :foreground) = CalendarEntryTile.colors(
                  kind,
                  scheme,
                );

                return Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(icon, size: 16, color: foreground),
                  label: Text(label, style: TextStyle(color: foreground)),
                  backgroundColor: background,
                  side: BorderSide(color: scheme.outlineVariant),
                );
              },
            ),
        ],
      ),
    );
  }
}
