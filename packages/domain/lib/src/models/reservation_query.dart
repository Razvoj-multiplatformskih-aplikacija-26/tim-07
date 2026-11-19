import '../enums.dart';
import '../ids.dart';

/// Kolona po kojoj se sortira tabela rezervacija.
enum ReservationSortKey { id, field, user, startTime, status }

/// Jedna strana velike liste: stavke te strane i ukupan broj za iste filtere
/// (odluka 6 u `docs/kt2-decisions.md`).
final class PagedResult<T> {
  final List<T> items;

  /// Ukupan broj zapisa za iste filtere, ne samo na ovoj strani.
  final int total;
  final int limit;
  final int offset;

  PagedResult({
    required Iterable<T> items,
    required this.total,
    required this.limit,
    required this.offset,
  }) : items = List.unmodifiable(items);

  bool get hasMore => offset + items.length < total;

  /// Redni broj ove strane, od nule.
  int get pageIndex => limit <= 0 ? 0 : offset ~/ limit;

  /// Broj strana za [total] zapisa; bar jedna, i kada nema zapisa.
  int get pageCount =>
      limit <= 0 || total == 0 ? 1 : (total + limit - 1) ~/ limit;
}

/// Šta vlasnik traži u tabeli rezervacija: filteri, pretraga, sortiranje i
/// strana. Server i lažni izvor primenjuju isti upit istim pravilom
/// (`searchReservations`), pa tabela ne zavisi od toga odakle dolaze podaci.
///
/// Objekat se ne menja; `with…` metode prave novi. Svaka promena filtera,
/// pretrage ili sortiranja vraća na prvu stranu, jer stara strana više ne
/// mora da postoji.
final class ReservationQuery {
  static const defaultLimit = 20;
  static const maxLimit = 100;

  /// Samo rezervacije ovog terena, ili sve.
  final FieldId? fieldId;

  /// Samo rezervacije u ovom stanju, ili sve.
  final ReservationStatus? status;

  /// Prvi i poslednji dan (uključeno) na koji rezervacija počinje. Koristi se
  /// samo kalendarski dan; sat se zanemaruje.
  final DateTime? fromDate;
  final DateTime? toDate;

  /// Tekst koji mora da se nalazi u imenu ili email-u korisnika. Prazan tekst
  /// znači da pretrage nema.
  final String search;

  final ReservationSortKey sortKey;
  final bool ascending;
  final int limit;
  final int offset;

  const ReservationQuery({
    this.fieldId,
    this.status,
    this.fromDate,
    this.toDate,
    this.search = '',
    this.sortKey = ReservationSortKey.startTime,
    this.ascending = true,
    this.limit = defaultLimit,
    this.offset = 0,
  }) : assert(limit >= 1 && limit <= maxLimit),
       assert(offset >= 0);

  /// Da li je neki filter ili pretraga uključena (sortiranje i strana se ne
  /// računaju).
  bool get hasFilters =>
      fieldId != null ||
      status != null ||
      fromDate != null ||
      toDate != null ||
      search.trim().isNotEmpty;

  ReservationQuery _with({
    required FieldId? fieldId,
    required ReservationStatus? status,
    required DateTime? fromDate,
    required DateTime? toDate,
    required String search,
    ReservationSortKey? sortKey,
    bool? ascending,
  }) => ReservationQuery(
    fieldId: fieldId,
    status: status,
    fromDate: fromDate == null ? null : _dayOf(fromDate),
    toDate: toDate == null ? null : _dayOf(toDate),
    search: search,
    sortKey: sortKey ?? this.sortKey,
    ascending: ascending ?? this.ascending,
    limit: limit,
  );

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  ReservationQuery withField(FieldId? value) => _with(
    fieldId: value,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    search: search,
  );

  ReservationQuery withStatus(ReservationStatus? value) => _with(
    fieldId: fieldId,
    status: value,
    fromDate: fromDate,
    toDate: toDate,
    search: search,
  );

  /// Opseg dana. Ako je kraj pre početka, zamenjuju se, da opseg nikad ne
  /// bude prazan zbog redosleda koji je vlasnik izabrao.
  ReservationQuery withDates({DateTime? from, DateTime? to}) {
    var start = from;
    var end = to;
    if (start != null && end != null && _dayOf(end).isBefore(_dayOf(start))) {
      (start, end) = (end, start);
    }
    return _with(
      fieldId: fieldId,
      status: status,
      fromDate: start,
      toDate: end,
      search: search,
    );
  }

  ReservationQuery withSearch(String value) => _with(
    fieldId: fieldId,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    search: value,
  );

  /// Isti sort: obrće smer. Druga kolona: počinje rastuće.
  ReservationQuery sortedBy(ReservationSortKey key) => _with(
    fieldId: fieldId,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    search: search,
    sortKey: key,
    ascending: key == sortKey ? !ascending : true,
  );

  /// Postavlja sortiranje bez obrtanja (kada smer dolazi izvana, npr. sa servera).
  ReservationQuery sortedExactly(
    ReservationSortKey key, {
    required bool ascending,
  }) => _with(
    fieldId: fieldId,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    search: search,
    sortKey: key,
    ascending: ascending,
  );

  /// Ista pretraga, druga strana. Samo ovo ne vraća na prvu stranu.
  ReservationQuery withOffset(int value) => ReservationQuery(
    fieldId: fieldId,
    status: status,
    fromDate: fromDate,
    toDate: toDate,
    search: search,
    sortKey: sortKey,
    ascending: ascending,
    limit: limit,
    offset: value < 0 ? 0 : value,
  );

  /// Bez filtera i pretrage; sortiranje i veličina strane ostaju.
  ReservationQuery withoutFilters() => _with(
    fieldId: null,
    status: null,
    fromDate: null,
    toDate: null,
    search: '',
  );

  @override
  bool operator ==(Object other) =>
      other is ReservationQuery &&
      other.fieldId == fieldId &&
      other.status == status &&
      other.fromDate == fromDate &&
      other.toDate == toDate &&
      other.search == search &&
      other.sortKey == sortKey &&
      other.ascending == ascending &&
      other.limit == limit &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(
    fieldId,
    status,
    fromDate,
    toDate,
    search,
    sortKey,
    ascending,
    limit,
    offset,
  );

  @override
  String toString() =>
      'ReservationQuery(field: $fieldId, status: $status, from: $fromDate, '
      'to: $toDate, search: "$search", sort: $sortKey '
      '${ascending ? 'asc' : 'desc'}, $offset+$limit)';
}
