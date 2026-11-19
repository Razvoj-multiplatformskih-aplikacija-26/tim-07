import 'package:domain/domain.dart';
import 'package:test/test.dart';

AppUser user(int id, String first, String last, {String? email}) => AppUser(
  id: UserId(id),
  firstName: first,
  lastName: last,
  email: email ?? '${first.toLowerCase()}.${last.toLowerCase()}@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: UserRole.user,
  createdAt: DateTime(2026),
);

final users = {
  for (final u in [
    user(1, 'Jovan', 'Petrović', email: 'jovan@example.com'),
    user(2, 'Đorđe', 'Šarić', email: 'djordje@example.com'),
    user(3, 'Ana', 'Anić', email: 'ana@example.com'),
  ])
    u.id: u,
};

const names = {1: 'Arena', 2: 'Centar', 3: 'Dvorana'};

Reservation reservation(
  int id, {
  int field = 1,
  int user = 1,
  required DateTime start,
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: ReservationId(id),
  fieldId: FieldId(field),
  userId: UserId(user),
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  totalPrice: 1000,
  status: status,
  createdAt: DateTime(2026, 1, 1),
);

DateTime at(int day, [int hour = 10, int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

final all = [
  reservation(1, field: 1, user: 1, start: at(20, 18)),
  reservation(
    2,
    field: 2,
    user: 2,
    start: at(20, 10),
    status: ReservationStatus.pending,
  ),
  reservation(
    3,
    field: 3,
    user: 3,
    start: at(21, 9),
    status: ReservationStatus.cancelled,
  ),
  reservation(
    4,
    field: 1,
    user: 2,
    start: at(22, 20),
    status: ReservationStatus.completed,
  ),
  reservation(5, field: 1, user: 1, start: at(20, 10)),
];

PagedResult<Reservation> run(
  ReservationQuery query, [
  Iterable<Reservation>? source,
]) => searchReservations(
  source ?? all,
  query,
  fieldName: (id) => names[id.value] ?? '',
  userOf: (id) => users[id],
);

List<int> ids(PagedResult<Reservation> page) => [
  for (final r in page.items) r.id.value,
];

void main() {
  group('bez filtera', () {
    test('sve rezervacije, po početku, pa po id', () {
      final page = run(const ReservationQuery());

      expect(ids(page), [2, 5, 1, 3, 4]);
      expect(page.total, 5);
      expect(page.limit, ReservationQuery.defaultLimit);
      expect(page.offset, 0);
      expect(page.hasMore, isFalse);
    });

    test('nema rezervacija: prazna strana', () {
      final page = run(const ReservationQuery(), const []);

      expect(page.items, isEmpty);
      expect(page.total, 0);
      expect(page.pageCount, 1);
    });
  });

  group('filteri', () {
    test('po terenu', () {
      expect(ids(run(const ReservationQuery(fieldId: FieldId(1)))), [5, 1, 4]);
    });

    test('po stanju', () {
      final page = run(
        const ReservationQuery(status: ReservationStatus.pending),
      );

      expect(ids(page), [2]);
    });

    test('po danu početka, oba kraja uključena', () {
      final page = run(
        ReservationQuery(fromDate: at(20, 23), toDate: at(21, 1)),
      );

      expect(ids(page), [2, 5, 1, 3]);
    });

    test('samo „od“ i samo „do“', () {
      expect(ids(run(ReservationQuery(fromDate: at(22)))), [4]);
      expect(ids(run(ReservationQuery(toDate: at(20)))), [2, 5, 1]);
    });

    test('opseg sa krajem pre početka se zamenjuje', () {
      final query = const ReservationQuery().withDates(
        from: at(21),
        to: at(20),
      );

      expect(query.fromDate, at(20, 0));
      expect(query.toDate, at(21, 0));
    });

    test('svi filteri rade zajedno', () {
      final page = run(
        ReservationQuery(
          fieldId: const FieldId(1),
          status: ReservationStatus.confirmed,
          fromDate: at(20),
          toDate: at(20),
        ),
      );

      expect(ids(page), [5, 1]);
    });

    test('filteri koji ništa ne nalaze daju praznu stranu', () {
      final page = run(
        const ReservationQuery(
          fieldId: FieldId(3),
          status: ReservationStatus.confirmed,
        ),
      );

      expect(page.items, isEmpty);
      expect(page.total, 0);
    });
  });

  group('pretraga po korisniku', () {
    test('ime, prezime i email, bez obzira na slova', () {
      expect(ids(run(const ReservationQuery(search: 'JOVAN'))), [5, 1]);
      expect(ids(run(const ReservationQuery(search: 'anić'))), [3]);
      expect(ids(run(const ReservationQuery(search: 'ana@exa'))), [3]);
    });

    test('dijakritici se ne razlikuju u oba smera', () {
      expect(ids(run(const ReservationQuery(search: 'petrovic'))), [5, 1]);
      expect(ids(run(const ReservationQuery(search: 'ĐORĐE'))), [2, 4]);
      expect(ids(run(const ReservationQuery(search: 'djordje sarić'))), [2, 4]);
    });

    test('svaka reč mora da se nađe', () {
      expect(ids(run(const ReservationQuery(search: 'jovan šarić'))), isEmpty);
      expect(ids(run(const ReservationQuery(search: 'jovan petrović'))), [
        5,
        1,
      ]);
    });

    test('razmaci i prazan tekst znače da pretrage nema', () {
      expect(run(const ReservationQuery(search: '   ')).total, 5);
      expect(const ReservationQuery(search: '  ').hasFilters, isFalse);
    });

    test('nepoznat korisnik se ne nalazi pretragom, ali se vidi bez nje', () {
      final stray = [...all, reservation(9, user: 99, start: at(23))];

      expect(run(const ReservationQuery(), stray).total, 6);
      expect(
        ids(run(const ReservationQuery(search: 'a'), stray)),
        isNot(contains(9)),
      );
    });

    test('pretraga i filter rade zajedno', () {
      final page = run(
        const ReservationQuery(
          search: 'jovan',
          status: ReservationStatus.confirmed,
        ),
      );

      expect(ids(page), [5, 1]);
    });
  });

  group('sortiranje', () {
    List<int> sorted(ReservationSortKey key, {bool ascending = true}) =>
        ids(run(ReservationQuery(sortKey: key, ascending: ascending)));

    test('po id, u oba smera', () {
      expect(sorted(ReservationSortKey.id), [1, 2, 3, 4, 5]);
      expect(sorted(ReservationSortKey.id, ascending: false), [5, 4, 3, 2, 1]);
    });

    test('po terenu pa po id', () {
      expect(sorted(ReservationSortKey.field), [1, 4, 5, 2, 3]);
      expect(sorted(ReservationSortKey.field, ascending: false), [
        3,
        2,
        1,
        4,
        5,
      ]);
    });

    test('po korisniku (prezime, ime)', () {
      // Anić, Petrović, Šarić.
      expect(sorted(ReservationSortKey.user), [3, 1, 5, 2, 4]);
    });

    test('po početku, opadajuće: jednaki počeci i dalje idu po id rastuće', () {
      expect(sorted(ReservationSortKey.startTime, ascending: false), [
        4,
        3,
        1,
        2,
        5,
      ]);
    });

    test('po stanju, redom iz domena', () {
      final order = [
        for (final id in sorted(ReservationSortKey.status))
          all.firstWhere((r) => r.id.value == id).status.index,
      ];

      expect(order, [...order]..sort());
    });

    test('sortedBy obrće smer iste kolone, a nova kolona počinje rastuće', () {
      const query = ReservationQuery();

      final flipped = query.sortedBy(ReservationSortKey.startTime);
      expect(flipped.ascending, isFalse);

      final other = flipped.sortedBy(ReservationSortKey.field);
      expect(other.sortKey, ReservationSortKey.field);
      expect(other.ascending, isTrue);
    });
  });

  group('strane', () {
    final many = [
      for (var i = 1; i <= 45; i++)
        reservation(i, start: DateTime(2026, 11, 1).add(Duration(hours: i))),
    ];

    test('prva strana nosi limit stavki i ukupan broj', () {
      final page = run(const ReservationQuery(), many);

      expect(page.items, hasLength(20));
      expect(page.total, 45);
      expect(page.hasMore, isTrue);
      expect(page.pageCount, 3);
      expect(page.pageIndex, 0);
    });

    test('poslednja strana je kraća', () {
      final page = run(const ReservationQuery().withOffset(40), many);

      expect(ids(page), [41, 42, 43, 44, 45]);
      expect(page.hasMore, isFalse);
      expect(page.pageIndex, 2);
    });

    test('strane se ne preklapaju i zajedno daju sve', () {
      final pages = [
        for (var offset = 0; offset < 45; offset += 20)
          ids(run(const ReservationQuery().withOffset(offset), many)),
      ];

      expect(pages.expand((p) => p).toList(), [
        for (var i = 1; i <= 45; i++) i,
      ]);
    });

    test('strana iza kraja je prazna, a ukupan broj ostaje', () {
      final page = run(const ReservationQuery().withOffset(100), many);

      expect(page.items, isEmpty);
      expect(page.total, 45);
    });

    test('promena filtera vraća na prvu stranu, a promena strane ne', () {
      final onThird = const ReservationQuery().withOffset(40);

      expect(onThird.withStatus(ReservationStatus.pending).offset, 0);
      expect(onThird.withSearch('a').offset, 0);
      expect(onThird.sortedBy(ReservationSortKey.id).offset, 0);
      expect(onThird.withOffset(20).offset, 20);
      expect(onThird.withOffset(-5).offset, 0);
    });
  });

  group('upit', () {
    test('withoutFilters čuva sortiranje', () {
      final query = ReservationQuery(
        fieldId: const FieldId(1),
        status: ReservationStatus.pending,
        fromDate: at(1),
        search: 'x',
        sortKey: ReservationSortKey.user,
        ascending: false,
      ).withoutFilters();

      expect(query.hasFilters, isFalse);
      expect(query.sortKey, ReservationSortKey.user);
      expect(query.ascending, isFalse);
    });

    test('jednakost i datumi bez sata', () {
      expect(
        const ReservationQuery().withDates(from: at(20, 17, 30)),
        const ReservationQuery().withDates(from: at(20, 1)),
      );
      expect(
        const ReservationQuery(),
        isNot(const ReservationQuery(offset: 20)),
      );
    });

    test('foldForSearch', () {
      expect(foldForSearch('Čačak ŽŠĆ Đ'), 'cacak zsc dj');
    });
  });
}
