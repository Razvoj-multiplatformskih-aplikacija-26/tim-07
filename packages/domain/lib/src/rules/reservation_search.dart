import '../ids.dart';
import '../models/app_user.dart';
import '../models/reservation.dart';
import '../models/reservation_query.dart';

/// Tekst za poređenje bez razlike u veličini slova i srpskim dijakriticima,
/// da „petrovic“ nađe „Petrović“, a „djordje“ i „đorđe“ isto.
String foldForSearch(String text) {
  const map = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'dj'};
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(map[char] ?? char);
  }
  return buffer.toString();
}

/// Primenjuje [query] na [reservations]: filteri, pretraga po korisniku,
/// sortiranje i strana. Ovo je jedino mesto gde se pravila tabele rezervacija
/// računaju; koriste ga server i lažni izvor, pa daju iste strane za iste
/// podatke.
///
/// - Filteri su spojeni sa „i“. Datumi se odnose na dan početka rezervacije.
/// - Pretraga traži svaku reč iz [ReservationQuery.search] u imenu ili
///   email-u korisnika. Rezervacija nepoznatog korisnika se ne nalazi
///   pretragom.
/// - Sortiranje je stabilno: pri jednakim vrednostima redosled je po `id`
///   rastuće, bez obzira na smer, pa se rezervacija ne pojavi na dve strane.
/// - [PagedResult.total] je broj rezervacija posle filtera, ne samo ove
///   strane; strana iza kraja je prazna, a `total` ostaje.
PagedResult<Reservation> searchReservations(
  Iterable<Reservation> reservations,
  ReservationQuery query, {
  required String Function(FieldId id) fieldName,
  required AppUser? Function(UserId id) userOf,
}) {
  final words = [
    for (final word in foldForSearch(query.search).split(RegExp(r'\s+')))
      if (word.isNotEmpty) word,
  ];

  bool matches(Reservation reservation) {
    if (query.fieldId != null && reservation.fieldId != query.fieldId) {
      return false;
    }
    if (query.status != null && reservation.status != query.status) {
      return false;
    }

    final day = _dayOf(reservation.startTime);
    // Upit može da nosi i sat (konstruktor ga ne briše): računa se samo dan.
    final from = query.fromDate == null ? null : _dayOf(query.fromDate!);
    final to = query.toDate == null ? null : _dayOf(query.toDate!);
    if (from != null && day.isBefore(from)) return false;
    if (to != null && day.isAfter(to)) return false;

    if (words.isNotEmpty) {
      final user = userOf(reservation.userId);
      if (user == null) return false;
      final haystack = foldForSearch(
        '${user.firstName} ${user.lastName} ${user.email}',
      );
      if (!words.every(haystack.contains)) return false;
    }

    return true;
  }

  final found = reservations.where(matches).toList();

  int compare(Reservation a, Reservation b) {
    final primary = switch (query.sortKey) {
      ReservationSortKey.id => 0,
      ReservationSortKey.field => foldForSearch(
        fieldName(a.fieldId),
      ).compareTo(foldForSearch(fieldName(b.fieldId))),
      ReservationSortKey.user => foldForSearch(
        _userName(userOf(a.userId)),
      ).compareTo(foldForSearch(_userName(userOf(b.userId)))),
      ReservationSortKey.startTime => a.startTime.compareTo(b.startTime),
      ReservationSortKey.status => a.status.index.compareTo(b.status.index),
    };
    final directed = query.ascending ? primary : -primary;
    if (directed != 0) return directed;

    final byId = a.id.value.compareTo(b.id.value);
    // `id` sortira i po sebi: tada smer važi i za njega.
    return query.sortKey == ReservationSortKey.id && !query.ascending
        ? -byId
        : byId;
  }

  found.sort(compare);

  return PagedResult(
    items: found.skip(query.offset).take(query.limit),
    total: found.length,
    limit: query.limit,
    offset: query.offset,
  );
}

String _userName(AppUser? user) =>
    user == null ? '' : '${user.lastName} ${user.firstName}';

DateTime _dayOf(DateTime time) => DateTime(time.year, time.month, time.day);
