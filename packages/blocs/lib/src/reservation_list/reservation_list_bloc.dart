import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

// --- događaji -------------------------------------------------------------

sealed class ReservationListEvent extends Equatable {
  const ReservationListEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj tabelu sa trenutnim filterima. Šalje se na početku i posle prijave.
final class ReservationListStarted extends ReservationListEvent {
  const ReservationListStarted();
}

/// Ponovo učitaj istu stranu, na primer posle potvrde ili otkazivanja
/// rezervacije ili za „Pokušaj ponovo“.
final class ReservationListRefreshed extends ReservationListEvent {
  const ReservationListRefreshed();
}

/// `null` znači svi tereni.
final class ReservationListFieldChanged extends ReservationListEvent {
  final FieldId? fieldId;

  const ReservationListFieldChanged(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

/// `null` znači sva stanja.
final class ReservationListStatusChanged extends ReservationListEvent {
  final ReservationStatus? status;

  const ReservationListStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

/// Opseg dana početka rezervacije; `null` na kraju znači bez ograničenja.
final class ReservationListDatesChanged extends ReservationListEvent {
  final DateTime? from;
  final DateTime? to;

  const ReservationListDatesChanged({this.from, this.to});

  @override
  List<Object?> get props => [from, to];
}

/// Tekst pretrage po korisniku. Učitava se tek kada vlasnik prestane da kuca.
final class ReservationListSearchChanged extends ReservationListEvent {
  final String text;

  const ReservationListSearchChanged(this.text);

  @override
  List<Object?> get props => [text];
}

/// Klik na zaglavlje kolone: ista kolona obrće smer, druga počinje rastuće.
final class ReservationListSortChanged extends ReservationListEvent {
  final ReservationSortKey key;

  const ReservationListSortChanged(this.key);

  @override
  List<Object?> get props => [key];
}

/// Strana od nule.
final class ReservationListPageRequested extends ReservationListEvent {
  final int pageIndex;

  const ReservationListPageRequested(this.pageIndex);

  @override
  List<Object?> get props => [pageIndex];
}

final class ReservationListFiltersCleared extends ReservationListEvent {
  const ReservationListFiltersCleared();
}

/// Odjava: zaboravi podatke i filtere da sledeći vlasnik ne vidi tuđe.
final class ReservationListCleared extends ReservationListEvent {
  const ReservationListCleared();
}

// --- stanja ---------------------------------------------------------------

/// Svako stanje nosi upit (filtere, sortiranje i stranu), pa ni učitavanje ni
/// greška ne brišu ono što je vlasnik izabrao.
sealed class ReservationListState extends Equatable {
  final ReservationQuery query;

  const ReservationListState(this.query);

  @override
  List<Object?> get props => [query];
}

final class ReservationListLoading extends ReservationListState {
  const ReservationListLoading([super.query = const ReservationQuery()]);
}

/// Strana sa bar jednom rezervacijom.
final class ReservationListLoaded extends ReservationListState {
  final PagedResult<Reservation> page;

  /// Upit je promenjen, a nova strana još nije stigla; [page] je prethodna.
  final bool refreshing;

  ReservationListLoaded({
    required ReservationQuery query,
    required this.page,
    this.refreshing = false,
  }) : super(query);

  ReservationListLoaded copyWith({ReservationQuery? query, bool? refreshing}) =>
      ReservationListLoaded(
        query: query ?? this.query,
        page: page,
        refreshing: refreshing ?? this.refreshing,
      );

  @override
  List<Object?> get props => [
    query,
    [for (final r in page.items) (r.id, r.status, r.startTime, r.endTime)],
    page.total,
    page.offset,
    refreshing,
  ];
}

/// Nema nijedne rezervacije, a filtera nema.
final class ReservationListEmpty extends ReservationListState {
  const ReservationListEmpty(super.query);
}

/// Filteri ili pretraga ne nalaze nijednu rezervaciju. Nije greška.
final class ReservationListNoMatches extends ReservationListState {
  const ReservationListNoMatches(super.query);
}

final class ReservationListError extends ReservationListState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const ReservationListError(super.query, this.message);

  @override
  List<Object?> get props => [query, message];
}

// --- Bloc -----------------------------------------------------------------

/// Tabela rezervacija u backoffice-u: filteri, pretraga, sortiranje i strane.
///
/// Svaku promenu pretvara u novi [ReservationQuery] i traži jednu stranu od
/// izvora (`ReservationSearchRepository`), koji upit računa istim pravilom na
/// serveru i u lažnom izvoru. Odgovor starijeg zahteva se odbacuje, pa spor
/// odgovor ne prepisuje noviji izbor.
final class ReservationListBloc
    extends Bloc<ReservationListEvent, ReservationListState> {
  final ReservationSearchRepository reservations;

  /// Koliko se čeka posle poslednjeg slova pretrage pre učitavanja.
  final Duration searchDelay;

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  ReservationListBloc({
    required this.reservations,
    this.searchDelay = const Duration(milliseconds: 300),
  }) : super(const ReservationListLoading()) {
    on<ReservationListStarted>((event, emit) => _load(emit, state.query));
    on<ReservationListRefreshed>((event, emit) => _load(emit, state.query));
    on<ReservationListFieldChanged>(
      (event, emit) => _change(emit, state.query.withField(event.fieldId)),
    );
    on<ReservationListStatusChanged>(
      (event, emit) => _change(emit, state.query.withStatus(event.status)),
    );
    on<ReservationListDatesChanged>(
      (event, emit) =>
          _change(emit, state.query.withDates(from: event.from, to: event.to)),
    );
    on<ReservationListSearchChanged>(_onSearchChanged);
    on<ReservationListSortChanged>(
      (event, emit) => _change(emit, state.query.sortedBy(event.key)),
    );
    on<ReservationListPageRequested>(_onPageRequested);
    on<ReservationListFiltersCleared>(
      (event, emit) => _change(emit, state.query.withoutFilters()),
    );
    on<ReservationListCleared>((event, emit) {
      _request++;
      emit(const ReservationListLoading());
    });
  }

  /// Novi upit; isti upit se ne učitava ponovo.
  Future<void> _change(
    Emitter<ReservationListState> emit,
    ReservationQuery query,
  ) async {
    if (query == state.query) return;
    await _load(emit, query);
  }

  Future<void> _onSearchChanged(
    ReservationListSearchChanged event,
    Emitter<ReservationListState> emit,
  ) async {
    final query = state.query.withSearch(event.text);
    if (query == state.query) return;
    await _load(emit, query, wait: searchDelay);
  }

  Future<void> _onPageRequested(
    ReservationListPageRequested event,
    Emitter<ReservationListState> emit,
  ) async {
    final query = state.query;
    await _change(emit, query.withOffset(event.pageIndex * query.limit));
  }

  Future<void> _load(
    Emitter<ReservationListState> emit,
    ReservationQuery query, {
    Duration wait = Duration.zero,
  }) async {
    final request = ++_request;
    final current = state;

    // Dok se čeka, tabela ostaje prethodna, a izabrani filteri se vide odmah.
    emit(
      current is ReservationListLoaded
          ? current.copyWith(query: query, refreshing: true)
          : ReservationListLoading(query),
    );

    try {
      if (wait > Duration.zero) {
        await Future<void>.delayed(wait);
        if (request != _request) return;
      }

      var asked = query;
      var page = await reservations.searchReservations(asked);
      if (request != _request) return;

      // Strana je nestala (poslednja rezervacija sa nje je otkazana ili
      // filter): prikaži poslednju strana koja postoji.
      if (page.items.isEmpty && page.total > 0 && asked.offset > 0) {
        asked = asked.withOffset(
          ((page.total - 1) ~/ asked.limit) * asked.limit,
        );
        page = await reservations.searchReservations(asked);
        if (request != _request) return;
      }

      if (page.total == 0) {
        emit(
          asked.hasFilters
              ? ReservationListNoMatches(asked)
              : ReservationListEmpty(asked),
        );
        return;
      }

      emit(ReservationListLoaded(query: asked, page: page));
    } catch (error) {
      if (request != _request) return;
      emit(ReservationListError(query, describeError(error)));
    }
  }
}
