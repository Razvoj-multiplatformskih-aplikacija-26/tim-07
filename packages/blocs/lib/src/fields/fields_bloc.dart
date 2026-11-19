import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';

import 'field_filters.dart';
import 'fields_event.dart';
import 'fields_state.dart';

/// Katalog javnih terena: učitavanje, pretraga, sport i redosled.
///
/// Ne zna odakle tereni dolaze (memorija ili server). Pretraga, sport i
/// redosled se primenjuju nad već učitanom listom, bez novog zahteva.
final class FieldsBloc extends Bloc<FieldsEvent, FieldsState> {
  final SportsFieldRepository repository;

  var _filters = const FieldFilters();

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  FieldsBloc({required this.repository}) : super(const FieldsInitial()) {
    on<FieldsRequested>(_onRequested);
    on<FieldsSearchChanged>(
      (event, emit) =>
          _onFiltersChanged(emit, _filters.copyWith(query: event.query)),
    );
    on<FieldsSportSelected>(
      (event, emit) => _onFiltersChanged(
        emit,
        event.sport == null
            ? _filters.copyWith(clearSport: true)
            : _filters.copyWith(sport: event.sport),
      ),
    );
    on<FieldsSortChanged>(
      (event, emit) =>
          _onFiltersChanged(emit, _filters.copyWith(sort: event.sort)),
    );
    on<FieldsFiltersReset>(
      (event, emit) => _onFiltersChanged(emit, const FieldFilters()),
    );
  }

  Future<void> _onRequested(
    FieldsRequested event,
    Emitter<FieldsState> emit,
  ) async {
    final request = ++_request;
    emit(FieldsLoading(filters: _filters));

    try {
      // Javan katalog: aktivni i odobreni tereni.
      final fields = await repository.getPublicFields();
      if (request != _request) return;

      // Izabran sport kog više nema u katalogu bi dao praznu listu bez čipa
      // kojim bi se vratio, pa se filter skida.
      final sport = _filters.sport;
      if (sport != null && !availableSports(fields).contains(sport)) {
        _filters = _filters.copyWith(clearSport: true);
      }

      emit(
        fields.isEmpty
            ? FieldsEmpty(filters: _filters)
            : FieldsLoaded(fields: fields, filters: _filters),
      );
    } catch (error) {
      if (request != _request) return;
      emit(FieldsError(describeError(error), filters: _filters));
    }
  }

  void _onFiltersChanged(Emitter<FieldsState> emit, FieldFilters filters) {
    _filters = filters;

    // Dok katalog nije učitan, filteri samo čekaju učitavanje.
    final current = state;
    if (current is FieldsLoaded) {
      emit(FieldsLoaded(fields: current.fields, filters: filters));
    }
  }
}
