import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Redosled u katalogu terena.
enum FieldSort {
  /// Kako ih je poslao izvor.
  none,
  priceAscending,
  priceDescending,
}

/// Šta je korisnik zadao u katalogu: pretraga, sport i redosled.
final class FieldFilters extends Equatable {
  final String query;

  /// `null` znači svi sportovi.
  final SportType? sport;
  final FieldSort sort;

  const FieldFilters({this.query = '', this.sport, this.sort = FieldSort.none});

  /// Ništa nije zadato, pa nema šta da se resetuje.
  bool get isDefault =>
      query.trim().isEmpty && sport == null && sort == FieldSort.none;

  /// `sport` se menja i kada je novi `null`, zato je ovo posebno polje.
  FieldFilters copyWith({
    String? query,
    SportType? sport,
    bool clearSport = false,
    FieldSort? sort,
  }) {
    return FieldFilters(
      query: query ?? this.query,
      sport: clearSport ? null : (sport ?? this.sport),
      sort: sort ?? this.sort,
    );
  }

  @override
  List<Object?> get props => [query, sport, sort];
}

/// Tereni koji odgovaraju filterima. Ne menja ulaznu listu.
///
/// Pretraga traži deo naziva, bez obzira na velika i mala slova. Sortiranje je
/// stabilno: terene iste cene ostavlja redom kojim su stigli.
List<SportsField> applyFieldFilters(
  Iterable<SportsField> fields,
  FieldFilters filters,
) {
  final query = filters.query.trim().toLowerCase();

  final matching = [
    for (final field in fields)
      if ((query.isEmpty || field.name.toLowerCase().contains(query)) &&
          (filters.sport == null || field.sport == filters.sport))
        field,
  ];

  // Dart `sort` nije stabilan, pa se redosled dolaska pamti uz svaki teren.
  final indexed = [for (var i = 0; i < matching.length; i++) (i, matching[i])];
  int byPrice(int a, int b) => a.compareTo(b);

  switch (filters.sort) {
    case FieldSort.none:
      break;
    case FieldSort.priceAscending:
      indexed.sort((a, b) {
        final price = byPrice(a.$2.pricePerHour, b.$2.pricePerHour);
        return price != 0 ? price : a.$1.compareTo(b.$1);
      });
    case FieldSort.priceDescending:
      indexed.sort((a, b) {
        final price = byPrice(b.$2.pricePerHour, a.$2.pricePerHour);
        return price != 0 ? price : a.$1.compareTo(b.$1);
      });
  }

  return [for (final entry in indexed) entry.$2];
}
