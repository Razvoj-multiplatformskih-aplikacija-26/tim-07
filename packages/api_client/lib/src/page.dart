/// Jedna strana velike liste sa servera (odluka 6 u docs/kt2-decisions.md).
final class Page<T> {
  final List<T> items;

  /// Ukupan broj zapisa za iste filtere, ne samo na ovoj strani.
  final int total;
  final int limit;
  final int offset;

  Page({
    required List<T> items,
    required this.total,
    required this.limit,
    required this.offset,
  }) : items = List.unmodifiable(items);

  bool get hasMore => offset + items.length < total;
}
