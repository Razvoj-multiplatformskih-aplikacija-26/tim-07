import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';

String periodLabel(StatsPeriod period) {
  final last = DateTime(period.to.year, period.to.month, period.to.day - 1);
  return switch (period.kind) {
    StatsPeriodKind.week => '${formatDate(period.from)} – ${formatDate(last)}',
    StatsPeriodKind.month => '${period.from.month.toString().padLeft(2, '0')}.${period.from.year}.',
  };
}

String _hours(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StatisticsBloc>();
    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<StatsPeriodKind>(
                  segments: const [
                    ButtonSegment(value: StatsPeriodKind.week, label: Text('Nedelja')),
                    ButtonSegment(value: StatsPeriodKind.month, label: Text('Mesec')),
                  ],
                  selected: {state.period.kind},
                  onSelectionChanged: (kinds) => bloc.add(StatisticsPeriodKindChanged(kinds.single)),
                ),
                IconButton(
                  tooltip: 'Prethodni period',
                  onPressed: () => bloc.add(const StatisticsPeriodMoved(-1)),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(periodLabel(state.period), style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  tooltip: 'Sledeći period',
                  onPressed: () => bloc.add(const StatisticsPeriodMoved(1)),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (state) {
              StatisticsLoading() => const Center(child: CircularProgressIndicator()),
              StatisticsError(:final message) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Statistika nije učitana', style: Theme.of(context).textTheme.titleMedium),
                    Text(message),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => bloc.add(const StatisticsStarted()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Pokušaj ponovo'),
                    ),
                  ],
                ),
              ),
              final StatisticsLoaded loaded when loaded.isEmpty => const Center(
                child: Text('Nema terena za prikaz statistike.'),
              ),
              final StatisticsLoaded loaded => _Report(report: loaded.report),
            },
          ),
        ],
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final OccupancyReport report;

  const _Report({required this.report});

  Widget _occupancy(BuildContext context, int percent, String name) => Semantics(
    label: '$name: zauzetost $percent posto',
    excludeSemantics: true,
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(value: percent.clamp(0, 100) / 100, minHeight: 8),
        ),
        const SizedBox(width: 8),
        Text('$percent %'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _Tile(label: 'Ukupna zauzetost', value: '${report.occupancyPercent} %'),
            _Tile(label: 'Realizovane rezervacije', value: '${report.completedCount}'),
            _Tile(label: 'Otkazane i odbijene', value: '${report.cancelledCount}'),
            _Tile(label: 'Aktivne', value: '${report.activeCount}'),
          ],
        ),
        const SizedBox(height: 24),
        Text('Po terenima', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Teren')),
              DataColumn(label: Text('Zauzetost')),
              DataColumn(label: Text('Zauzeto / raspoloživo')),
              DataColumn(label: Text('Realizovane'), numeric: true),
              DataColumn(label: Text('Otkazane i odbijene'), numeric: true),
              DataColumn(label: Text('Aktivne'), numeric: true),
            ],
            rows: [
              for (final field in report.fields)
                DataRow(
                  cells: [
                    DataCell(Text(field.fieldName)),
                    DataCell(_occupancy(context, field.occupancyPercent, field.fieldName)),
                    DataCell(Text('${_hours(field.bookedMinutes)} / ${_hours(field.availableMinutes)}')),
                    DataCell(Text('${field.completedCount}')),
                    DataCell(Text('${field.cancelledCount}')),
                    DataCell(Text('${field.activeCount}')),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;

  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
