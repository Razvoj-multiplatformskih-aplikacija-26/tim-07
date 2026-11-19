import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

import 'field_filters.dart';

sealed class FieldsEvent extends Equatable {
  const FieldsEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj katalog (i „Pokušaj ponovo“, i povuci za osvežavanje). Filteri ostaju.
final class FieldsRequested extends FieldsEvent {
  const FieldsRequested();
}

/// Korisnik kuca u polje za pretragu.
final class FieldsSearchChanged extends FieldsEvent {
  final String query;

  const FieldsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Brzi filter: izabran sport, ili `null` za sve.
final class FieldsSportSelected extends FieldsEvent {
  final SportType? sport;

  const FieldsSportSelected(this.sport);

  @override
  List<Object?> get props => [sport];
}

final class FieldsSortChanged extends FieldsEvent {
  final FieldSort sort;

  const FieldsSortChanged(this.sort);

  @override
  List<Object?> get props => [sort];
}

/// Vrati pretragu, sport i redosled na početne vrednosti.
final class FieldsFiltersReset extends FieldsEvent {
  const FieldsFiltersReset();
}
