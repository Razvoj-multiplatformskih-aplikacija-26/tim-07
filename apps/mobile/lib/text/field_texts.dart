import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';

/// Nazivi redosleda u listi terena.
String sortLabel(FieldSort sort) {
  return switch (sort) {
    FieldSort.none => 'Podrazumevano',
    FieldSort.priceAscending => 'Cena: od najniže',
    FieldSort.priceDescending => 'Cena: od najviše',
  };
}

/// Šta piše uz termin.
String slotStateLabel(SlotState state) {
  return switch (state) {
    SlotState.free => 'Slobodan termin',
    SlotState.taken => 'Zauzet termin',
    SlotState.blocked => 'Teren je blokiran',
    SlotState.past => 'Termin je prošao',
  };
}
