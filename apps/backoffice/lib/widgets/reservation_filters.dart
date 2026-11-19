import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/directory.dart';
import '../text/labels.dart';
import 'reservation_status_chip.dart';

/// Filteri, pretraga i poništavanje iznad tabele rezervacija.
///
/// Vrednosti dolaze iz `ReservationListBloc`-a (upit je u njegovom stanju), a
/// widget samo šalje događaje. Lista terena je iz `DirectoryCubit`-a, a stanja
/// iz domena, pa ništa nije ispisano ručno.
class ReservationFilters extends StatefulWidget {
  const ReservationFilters({super.key});

  @override
  State<ReservationFilters> createState() => _ReservationFiltersState();
}

class _ReservationFiltersState extends State<ReservationFilters> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDates(BuildContext context, ReservationQuery query) async {
    final bloc = context.read<ReservationListBloc>();
    final today = DateUtils.dateOnly(DateTime.now());
    final from = query.fromDate;
    final to = query.toDate;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: DateTime(today.year + 5),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
      helpText: 'Datum početka rezervacije',
      saveText: 'Primeni',
    );

    if (picked != null) {
      bloc.add(ReservationListDatesChanged(from: picked.start, to: picked.end));
    }
  }

  static String _datesLabel(ReservationQuery query) {
    final from = query.fromDate;
    final to = query.toDate;

    if (from == null && to == null) return 'Svi datumi';
    if (from != null && to != null && from == to) return formatDate(from);
    if (from != null && to != null) {
      return '${formatDayMonth(from)} - ${formatDate(to)}';
    }
    return from != null ? 'od ${formatDate(from)}' : 'do ${formatDate(to!)}';
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ReservationListBloc>();
    final directory = context.watch<DirectoryCubit>().state;
    final theme = Theme.of(context);

    return BlocConsumer<ReservationListBloc, ReservationListState>(
      // Tekst se menja spolja samo kada se filteri poništavaju; dok vlasnik
      // kuca, upit već nosi isti tekst, pa se polje ne dira.
      listenWhen: (previous, current) =>
          previous.query.search != current.query.search,
      listener: (context, state) {
        if (_search.text != state.query.search) {
          _search.text = state.query.search;
        }
      },
      buildWhen: (previous, current) => previous.query != current.query,
      builder: (context, state) {
        final query = state.query;
        final fields = directory.fields.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Pretraga po korisniku',
                    hintText: 'Ime, prezime ili email',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: query.search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Obriši pretragu',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              bloc.add(const ReservationListSearchChanged(''));
                            },
                          ),
                  ),
                  onChanged: (text) =>
                      bloc.add(ReservationListSearchChanged(text)),
                ),
              ),
              _Dropdown<FieldId?>(
                label: 'Teren',
                value: query.fieldId,
                allLabel: 'Svi tereni',
                options: [for (final field in fields) (field.id, field.name)],
                onChanged: (id) => bloc.add(ReservationListFieldChanged(id)),
              ),
              _Dropdown<ReservationStatus?>(
                label: 'Stanje',
                value: query.status,
                allLabel: 'Sva stanja',
                options: [
                  for (final status in ReservationStatus.values)
                    (status, ReservationStatusChip.label(status)),
                ],
                onChanged: (status) =>
                    bloc.add(ReservationListStatusChanged(status)),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDates(context, query),
                icon: const Icon(Icons.date_range),
                label: Text('Datum: ${_datesLabel(query)}'),
              ),
              if (query.fromDate != null || query.toDate != null)
                IconButton(
                  tooltip: 'Obriši datume',
                  icon: const Icon(Icons.event_busy_outlined),
                  onPressed: () =>
                      bloc.add(const ReservationListDatesChanged()),
                ),
              if (query.hasFilters)
                TextButton.icon(
                  onPressed: () =>
                      bloc.add(const ReservationListFiltersCleared()),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(
                    'Poništi filtere',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Padajuća lista sa stavkom „sve“ (vrednost `null`) na početku.
class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String allLabel;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T?>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: [
              DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
              for (final (option, text) in options)
                DropdownMenuItem<T?>(
                  value: option,
                  child: Text(text, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
