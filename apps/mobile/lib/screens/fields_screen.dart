import 'package:blocs/blocs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../text/field_texts.dart';
import '../text/reservation_texts.dart';
import '../widgets/account_button.dart';
import '../widgets/field_card.dart';
import '../widgets/fields_simulation_menu.dart';

/// Katalog javnih terena. Tereni, pretraga, sport i redosled su u `FieldsBloc`-u;
/// ekran samo šalje događaje i crta stanje.
class FieldsScreen extends StatefulWidget {
  const FieldsScreen({super.key});

  @override
  State<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends State<FieldsScreen> {
  // Tekst u polju za pretragu pripada ekranu, a filter Bloc-u.
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Ne `late final` sa inicijalizacijom: ona bi se izvršila tek u `dispose`,
    // ako se katalog nikad ne iscrta (greška, učitavanje), kada je `context` nebezbedan.
    _search = TextEditingController(
      text: context.read<FieldsBloc>().state.filters.query,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => context.read<FieldsBloc>().add(const FieldsRequested());

  void _reset() {
    _search.clear();
    context.read<FieldsBloc>().add(const FieldsFiltersReset());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportski tereni'),
        actions: const [AccountButton(), FieldsSimulationMenu()],
      ),
      body: BlocBuilder<FieldsBloc, FieldsState>(
        builder: (context, state) {
          return switch (state) {
            FieldsInitial() || FieldsLoading() => const _LoadingView(),
            FieldsError(:final message) => _ErrorView(
              message: message,
              onRetry: _reload,
            ),
            FieldsEmpty() => _EmptyView(onReload: _reload),
            FieldsLoaded() => _catalog(context, state),
          };
        },
      ),
    );
  }

  Widget _catalog(BuildContext context, FieldsLoaded state) {
    final filters = state.filters;
    final bloc = context.read<FieldsBloc>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (value) => bloc.add(FieldsSearchChanged(value)),
            decoration: InputDecoration(
              hintText: 'Pretraži terene...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.sort),
              const SizedBox(width: 8),
              const Text('Sortiraj:'),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<FieldSort>(
                  // Ključ prati izbor, da se polje osveži i kada ga Bloc vrati (reset).
                  key: ValueKey(filters.sort),
                  initialValue: filters.sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final sort in FieldSort.values)
                      DropdownMenuItem(
                        value: sort,
                        child: Text(sortLabel(sort)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) bloc.add(FieldsSortChanged(value));
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _SportChip(
                label: 'Svi',
                selected: filters.sport == null,
                onSelected: () => bloc.add(const FieldsSportSelected(null)),
              ),
              for (final sport in state.sports)
                _SportChip(
                  label: sportLabel(sport),
                  selected: filters.sport == sport,
                  onSelected: () => bloc.add(FieldsSportSelected(sport)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pronađeno terena: ${state.visible.length}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (!filters.isDefault)
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Resetuj'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: state.visible.isEmpty
              ? const Center(child: Text('Nema pronađenih terena.'))
              : RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.visible.length,
                    itemBuilder: (context, index) {
                      final field = state.visible[index];

                      return FieldCard(
                        name: field.name,
                        location: field.address,
                        sport: field.sport,
                        pricePerHour: field.pricePerHour,
                        onTap: () => context.push('/fields/${field.id.value}'),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SportChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _SportChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Učitavanje terena...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Tereni nisu učitani', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onReload;

  const _EmptyView({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stadium_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Trenutno nema terena', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            const Text('Pokušajte ponovo kasnije.'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Osveži'),
            ),
          ],
        ),
      ),
    );
  }
}
