import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

/// Traka ispod tabele: koliko je prikazano od ukupnog broja i prelazak na
/// drugu stranu. Broj strana dolazi sa servera (`total`), pa tabela ne učitava
/// više nego što prikazuje.
class ReservationsPager extends StatelessWidget {
  final PagedResult<Reservation> page;
  final ValueChanged<int> onPage;

  const ReservationsPager({
    super.key,
    required this.page,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = page.total == 0 ? 0 : page.offset + 1;
    final last = page.offset + page.items.length;
    final index = page.pageIndex;
    final count = page.pageCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Prikazano $first-$last od ${page.total}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Prethodna strana',
                icon: const Icon(Icons.chevron_left),
                onPressed: index > 0 ? () => onPage(index - 1) : null,
              ),
              Text('Strana ${index + 1} od $count'),
              IconButton(
                tooltip: 'Sledeća strana',
                icon: const Icon(Icons.chevron_right),
                onPressed: index < count - 1 ? () => onPage(index + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
