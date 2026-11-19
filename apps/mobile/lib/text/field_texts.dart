import 'package:blocs/blocs.dart';

/// Nazivi redosleda u listi terena.
String sortLabel(FieldSort sort) {
  return switch (sort) {
    FieldSort.none => 'Podrazumevano',
    FieldSort.priceAscending => 'Cena: od najniže',
    FieldSort.priceDescending => 'Cena: od najviše',
  };
}
