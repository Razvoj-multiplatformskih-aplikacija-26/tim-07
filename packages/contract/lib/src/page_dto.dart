import 'json.dart';

/// Deo velike liste (odluka 6): `{"items": [...], "total": 87, "limit": 20, "offset": 40}`.
final class PageDto<T> {
  final List<T> items;

  /// Ukupan broj zapisa za iste filtere, ne samo na ovoj strani.
  final int total;
  final int limit;
  final int offset;

  PageDto({
    required List<T> items,
    required this.total,
    required this.limit,
    required this.offset,
  }) : items = List.unmodifiable(items);

  bool get hasMore => offset + items.length < total;

  Map<String, Object?> toJson(
    Map<String, Object?> Function(T item) itemToJson,
  ) => {
    'items': [for (final item in items) itemToJson(item)],
    'total': total,
    'limit': limit,
    'offset': offset,
  };

  factory PageDto.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, Object?> item) itemFromJson,
  ) => PageDto(
    items: [for (final item in jsonObjects(json, 'items')) itemFromJson(item)],
    total: jsonInt(json, 'total'),
    limit: jsonInt(json, 'limit'),
    offset: jsonInt(json, 'offset'),
  );
}
