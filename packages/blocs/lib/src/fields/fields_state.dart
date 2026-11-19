import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

import 'field_filters.dart';

/// Katalog terena. Svako stanje nosi filtere, pa ih ni učitavanje ni greška
/// ne brišu (isto kao u primeru Rafstoran, gde svako stanje nosi dan i broj osoba).
sealed class FieldsState extends Equatable {
  final FieldFilters filters;

  const FieldsState({this.filters = const FieldFilters()});

  /// Svi učitani tereni, ili prazna lista dok nisu učitani.
  List<SportsField> get fields => const [];

  @override
  List<Object?> get props => [filters];
}

final class FieldsInitial extends FieldsState {
  const FieldsInitial({super.filters});
}

final class FieldsLoading extends FieldsState {
  const FieldsLoading({super.filters});
}

final class FieldsError extends FieldsState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const FieldsError(this.message, {super.filters});

  @override
  List<Object?> get props => [...super.props, message];
}

/// Izvor nema nijedan javan teren. Nije isto što i „filteri ništa ne pronalaze“.
final class FieldsEmpty extends FieldsState {
  const FieldsEmpty({super.filters});
}

final class FieldsLoaded extends FieldsState {
  @override
  final List<SportsField> fields;

  /// Tereni koji odgovaraju filterima, već u traženom redosledu. Može biti
  /// prazna lista kada filteri ništa ne pronađu.
  final List<SportsField> visible;

  FieldsLoaded({required List<SportsField> fields, required super.filters})
    : fields = List.unmodifiable(fields),
      visible = List.unmodifiable(applyFieldFilters(fields, filters));

  @override
  List<Object?> get props => [...super.props, fields];
}
