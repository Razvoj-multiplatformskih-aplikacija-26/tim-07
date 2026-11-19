import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Naziv terena iz kataloga koji je učitao `FieldsBloc`, ne iz demo podataka.
extension FieldNames on BuildContext {
  /// Naziv terena, ili „Teren #id“ dok katalog nije učitan ili kada tog terena
  /// u njemu nema (npr. više nije javan). Ekran se ponovo crta kada se katalog učita.
  String fieldName(FieldId id) {
    final fields = select<FieldsBloc, List<SportsField>>(
      (bloc) => bloc.state.fields,
    );

    for (final field in fields) {
      if (field.id == id) return field.name;
    }
    return 'Teren #${id.value}';
  }
}
