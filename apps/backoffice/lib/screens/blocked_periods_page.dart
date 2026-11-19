import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../text/labels.dart';
import '../widgets/add_block_dialog.dart';

/// Blokiranje termina terena (održavanje, događaji).
///
/// Pravila (blokada ne sme preko potvrđene rezervacije, vlasnik blokira samo
/// svoje terene) su u `BlockedPeriodsBloc`-u i domenu; stranica šalje događaje
/// i crta stanje, uključujući razlog kada blokada nije dozvoljena.
class BlockedPeriodsPage extends StatelessWidget {
  const BlockedPeriodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BlockedPeriodsBloc, BlockedPeriodsState>(
      builder: (context, state) {
        return switch (state) {
          BlockedPeriodsLoading() => const _Notice(
            icon: CircularProgressIndicator(),
            title: 'Učitavanje blokada...',
          ),
          BlockedPeriodsError(:final message) => _Notice(
            icon: Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            title: 'Blokade nisu učitane',
            message: message,
            action: FilledButton.icon(
              autofocus: true,
              onPressed: () => context.read<BlockedPeriodsBloc>().add(
                const BlockedPeriodsStarted(),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ),
          BlockedPeriodsNoFields() => const _Notice(
            icon: Icon(Icons.stadium_outlined, size: 48),
            title: 'Nemate nijedan teren',
            message: 'Blokirati možete samo termine svojih terena.',
          ),
          final BlockedPeriodsLoaded loaded => _Loaded(state: loaded),
        };
      },
    );
  }
}

class _Loaded extends StatelessWidget {
  final BlockedPeriodsLoaded state;

  const _Loaded({required this.state});

  Future<void> _add(BuildContext context) async {
    final bloc = context.read<BlockedPeriodsBloc>();
    final draft = await showAddBlockDialog(context, field: state.field);

    if (draft != null) {
      bloc.add(
        BlockedPeriodAddRequested(
          startTime: draft.start,
          endTime: draft.end,
          reason: draft.reason,
        ),
      );
    }
  }

  Future<void> _remove(BuildContext context, BlockedPeriod period) async {
    final bloc = context.read<BlockedPeriodsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ukloniti blokadu?'),
        content: Text(
          '${formatDateTimeRange(period.startTime, period.endTime)} '
          'ponovo postaje dostupno za rezervaciju.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Da, ukloni'),
          ),
        ],
      ),
    );

    if (confirmed == true) bloc.add(BlockedPeriodRemoveRequested(period));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<BlockedPeriodsBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text('Teren', style: theme.textTheme.titleMedium),
              const SizedBox(width: 12),
              DropdownButton<FieldId>(
                value: state.field.id,
                items: [
                  for (final field in state.fields)
                    DropdownMenuItem(value: field.id, child: Text(field.name)),
                ],
                onChanged: state.busy
                    ? null
                    : (id) {
                        if (id != null) {
                          bloc.add(BlockedPeriodsFieldSelected(id));
                        }
                      },
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: state.busy ? null : () => _add(context),
                icon: const Icon(Icons.block),
                label: const Text('Dodaj blokadu'),
              ),
            ],
          ),
        ),
        if (state.busy) const LinearProgressIndicator(),
        if (state.message case final message?)
          // Poruka je u živoj oblasti, da je čitač ekrana pročita.
          Semantics(
            liveRegion: true,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: state.blocks.isEmpty
              ? const _Notice(
                  icon: Icon(Icons.event_available_outlined, size: 48),
                  title: 'Nema blokada',
                  message:
                      'Svi termini ovog terena su otvoreni za rezervaciju.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    for (final period in state.blocks)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.block),
                          title: Text(
                            formatDateTimeRange(
                              period.startTime,
                              period.endTime,
                            ),
                          ),
                          subtitle: Text(period.reason ?? 'Bez razloga'),
                          trailing: IconButton(
                            tooltip: 'Ukloni blokadu',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: state.busy
                                ? null
                                : () => _remove(context, period),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? message;
  final Widget? action;

  const _Notice({
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = this.message;
    final action = this.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
