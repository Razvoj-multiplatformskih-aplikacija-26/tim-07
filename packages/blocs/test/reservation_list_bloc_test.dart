import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

// Sada je 1. 11. 2026., a rezervacije su u decembru, dovoljno unapred da mogu
// da se otkažu.
final now = DateTime(2026, 11, 1, 9);

AppUser person(int id, String first, String last) => AppUser(
  id: UserId(id),
  firstName: first,
  lastName: last,
  email: '${first.toLowerCase()}@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: UserRole.user,
  createdAt: DateTime(2026),
);

final users = [
  person(1, 'Jovan', 'Petrović'),
  person(2, 'Marko', 'Marković'),
  person(3, 'Ana', 'Anić'),
];

SportsField field(int id, String name) => SportsField(
  id: FieldId(id),
  ownerId: const UserId(100),
  name: name,
  description: 'Opis',
  sport: SportType.padel,
  address: 'A',
  city: 'Beograd',
  pricePerHour: 3000,
  contactPhone: '060',
  confirmationMode: ConfirmationMode.automatic,
);

final fields = [field(1, 'Arena'), field(2, 'Centar')];

Reservation reservation(
  int id, {
  int field = 1,
  int user = 1,
  int day = 10,
  int hour = 10,
  ReservationStatus status = ReservationStatus.confirmed,
}) => Reservation(
  id: ReservationId(id),
  fieldId: FieldId(field),
  userId: UserId(user),
  startTime: DateTime(2026, 12, day, hour),
  endTime: DateTime(2026, 12, day, hour + 1),
  totalPrice: 3000,
  status: status,
  createdAt: DateTime(2026, 10, 1),
);

/// Propušta pozive pravom izvoru, broji ih i može da ih zadrži ili odbije.
final class _Source implements ReservationSearchRepository {
  final ReservationSearchRepository inner;
  final calls = <ReservationQuery>[];
  Object? error;

  /// Prvi poziv čeka na ovo, pa drugi može da ga pretekne.
  Completer<void>? gate;

  _Source(this.inner);

  @override
  Future<PagedResult<Reservation>> searchReservations(
    ReservationQuery query,
  ) async {
    calls.add(query);
    final pending = gate;
    if (pending != null) {
      gate = null;
      await pending.future;
    }
    final failure = error;
    if (failure != null) throw failure;
    return inner.searchReservations(query);
  }
}

/// Sledeće stanje koje nije učitavanje, ni osvežavanje.
Future<ReservationListState> settled(ReservationListBloc bloc) =>
    bloc.stream.firstWhere(
      (state) =>
          state is! ReservationListLoading &&
          !(state is ReservationListLoaded && state.refreshing),
    );

Future<ReservationListState> send(
  ReservationListBloc bloc,
  ReservationListEvent event,
) async {
  final next = settled(bloc);
  bloc.add(event);
  return next;
}

List<int> ids(ReservationListState state) => [
  for (final r in (state as ReservationListLoaded).page.items) r.id.value,
];

void main() {
  late FakeReservationRepository store;
  late _Source source;
  late ReservationListBloc bloc;

  void build(List<Reservation> reservations) {
    store = FakeReservationRepository(
      clock: () => now,
      reservations: reservations,
      fields: fields,
      users: users,
    );
    source = _Source(store);
    bloc = ReservationListBloc(
      reservations: source,
      searchDelay: const Duration(milliseconds: 20),
    );
  }

  setUp(() {
    build([
      reservation(1, field: 1, user: 1, day: 10, hour: 18),
      reservation(
        2,
        field: 2,
        user: 2,
        day: 10,
        hour: 10,
        status: ReservationStatus.pending,
      ),
      reservation(3, field: 1, user: 3, day: 11, hour: 9),
      reservation(
        4,
        field: 2,
        user: 1,
        day: 12,
        hour: 20,
        status: ReservationStatus.completed,
      ),
      reservation(5, field: 1, user: 2, day: 10, hour: 12),
    ]);
  });

  tearDown(() => bloc.close());

  group('početak', () {
    test('prvo učitavanje, pa prva strana sa ukupnim brojem', () async {
      final states = <ReservationListState>[];
      bloc.stream.listen(states.add);

      final loaded = await send(bloc, const ReservationListStarted());

      expect(states.first, isA<ReservationListLoading>());
      expect(loaded, isA<ReservationListLoaded>());
      expect(ids(loaded), [2, 5, 1, 3, 4]);
      expect((loaded as ReservationListLoaded).page.total, 5);
      expect(loaded.query, const ReservationQuery());
      expect(loaded.refreshing, isFalse);
    });

    test('bez rezervacija: prazno stanje, ne greška', () async {
      build(const []);

      final state = await send(bloc, const ReservationListStarted());

      expect(state, isA<ReservationListEmpty>());
    });

    test('greška izvora je stanje greške sa porukom i upitom', () async {
      source.error = const ServerUnreachableException();

      final state = await send(bloc, const ReservationListStarted());

      expect(state, isA<ReservationListError>());
      expect(
        (state as ReservationListError).message,
        describeError(const ServerUnreachableException()),
      );
      expect(state.query, const ReservationQuery());
    });

    test('„Pokušaj ponovo“ posle greške učitava iste filtere', () async {
      await send(bloc, const ReservationListStarted());
      source.error = const ServerUnreachableException();
      final failed = await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.confirmed),
      );
      expect(failed, isA<ReservationListError>());

      source.error = null;
      final loaded = await send(bloc, const ReservationListRefreshed());

      expect(loaded.query.status, ReservationStatus.confirmed);
      expect(ids(loaded), [5, 1, 3]);
    });
  });

  group('filteri', () {
    setUp(() async {
      await send(bloc, const ReservationListStarted());
    });

    test('po terenu', () async {
      final state = await send(
        bloc,
        const ReservationListFieldChanged(FieldId(2)),
      );

      expect(ids(state), [2, 4]);
      expect(state.query.fieldId, const FieldId(2));
    });

    test('po stanju', () async {
      final state = await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.pending),
      );

      expect(ids(state), [2]);
    });

    test('po datumu, uključujući oba kraja', () async {
      final state = await send(
        bloc,
        ReservationListDatesChanged(
          from: DateTime(2026, 12, 11),
          to: DateTime(2026, 12, 12),
        ),
      );

      expect(ids(state), [3, 4]);
    });

    test('pretraga po korisniku ne gleda dijakritike', () async {
      final state = await send(
        bloc,
        const ReservationListSearchChanged('petrovic'),
      );

      expect(ids(state), [1, 4]);
    });

    test('svi filteri zajedno, a svaki ostaje u upitu', () async {
      await send(bloc, const ReservationListFieldChanged(FieldId(1)));
      await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.confirmed),
      );
      await send(
        bloc,
        ReservationListDatesChanged(
          from: DateTime(2026, 12, 10),
          to: DateTime(2026, 12, 10),
        ),
      );
      final state = await send(
        bloc,
        const ReservationListSearchChanged('marko'),
      );

      expect(ids(state), [5]);
      expect(state.query.fieldId, const FieldId(1));
      expect(state.query.status, ReservationStatus.confirmed);
      expect(state.query.fromDate, DateTime(2026, 12, 10));
      expect(state.query.search, 'marko');
    });

    test('filteri bez rezultata: „nema poklapanja“, ne greška', () async {
      final state = await send(
        bloc,
        const ReservationListSearchChanged('nepostojeci'),
      );

      expect(state, isA<ReservationListNoMatches>());
      expect(state.query.search, 'nepostojeci');
    });

    test('poništavanje filtera vraća sve rezervacije', () async {
      await send(bloc, const ReservationListSearchChanged('nepostojeci'));

      final state = await send(bloc, const ReservationListFiltersCleared());

      expect(ids(state), [2, 5, 1, 3, 4]);
      expect(state.query.hasFilters, isFalse);
    });

    test('poništavanje čuva sortiranje', () async {
      await send(bloc, const ReservationListSortChanged(ReservationSortKey.id));
      await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.pending),
      );

      final state = await send(bloc, const ReservationListFiltersCleared());

      expect(state.query.sortKey, ReservationSortKey.id);
    });

    test('isti filter ponovo ne učitava ništa', () async {
      final calls = source.calls.length;

      bloc.add(const ReservationListStatusChanged(null));
      bloc.add(const ReservationListSearchChanged(''));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(source.calls.length, calls);
    });

    test(
      'promena filtera odmah menja upit, a tabela ostaje do odgovora',
      () async {
        final states = <ReservationListState>[];
        bloc.stream.listen(states.add);

        await send(
          bloc,
          const ReservationListStatusChanged(ReservationStatus.pending),
        );

        final pending = states.first as ReservationListLoaded;
        expect(pending.refreshing, isTrue);
        expect(pending.query.status, ReservationStatus.pending);
        expect(pending.page.items, hasLength(5));
      },
    );
  });

  group('pretraga', () {
    test('brzo kucanje je jedan zahtev, sa poslednjim tekstom', () async {
      await send(bloc, const ReservationListStarted());
      final calls = source.calls.length;

      final next = settled(bloc);
      for (final text in ['j', 'jo', 'jov', 'jovan']) {
        bloc.add(ReservationListSearchChanged(text));
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final state = await next;

      expect(source.calls.length, calls + 1);
      expect(state.query.search, 'jovan');
      expect(ids(state), [1, 4]);
    });
  });

  group('sortiranje', () {
    setUp(() async {
      await send(bloc, const ReservationListStarted());
    });

    test('klik na kolonu sortira rastuće, drugi klik obrće', () async {
      final first = await send(
        bloc,
        const ReservationListSortChanged(ReservationSortKey.id),
      );
      expect(ids(first), [1, 2, 3, 4, 5]);
      expect(first.query.ascending, isTrue);

      final second = await send(
        bloc,
        const ReservationListSortChanged(ReservationSortKey.id),
      );
      expect(ids(second), [5, 4, 3, 2, 1]);
      expect(second.query.ascending, isFalse);
    });

    test('druga kolona opet počinje rastuće', () async {
      await send(bloc, const ReservationListSortChanged(ReservationSortKey.id));
      await send(bloc, const ReservationListSortChanged(ReservationSortKey.id));

      final state = await send(
        bloc,
        const ReservationListSortChanged(ReservationSortKey.field),
      );

      expect(state.query.sortKey, ReservationSortKey.field);
      expect(state.query.ascending, isTrue);
    });

    test('sortiranje se vidi zajedno sa filterom', () async {
      await send(bloc, const ReservationListFieldChanged(FieldId(1)));

      final state = await send(
        bloc,
        const ReservationListSortChanged(ReservationSortKey.user),
      );

      // Anić, Marković, Petrović.
      expect(ids(state), [3, 5, 1]);
    });
  });

  group('strane', () {
    setUp(() {
      build([
        for (var i = 1; i <= 45; i++)
          reservation(i, day: 1 + (i % 28), hour: 8 + (i % 12)),
      ]);
    });

    test('prva strana ima 20 stavki, a ukupno 45', () async {
      final state = await send(bloc, const ReservationListStarted());

      final page = (state as ReservationListLoaded).page;
      expect(page.items, hasLength(20));
      expect(page.total, 45);
      expect(page.pageCount, 3);
    });

    test('tražena strana se učitava, a poslednja je kraća', () async {
      await send(bloc, const ReservationListStarted());

      final state = await send(bloc, const ReservationListPageRequested(2));

      expect((state as ReservationListLoaded).page.items, hasLength(5));
      expect(state.page.pageIndex, 2);
      expect(state.query.offset, 40);
    });

    test('promena filtera vraća na prvu stranu', () async {
      await send(bloc, const ReservationListStarted());
      await send(bloc, const ReservationListPageRequested(2));

      final state = await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.confirmed),
      );

      expect(state.query.offset, 0);
    });

    test('ista strana ponovo ne učitava ništa', () async {
      await send(bloc, const ReservationListStarted());
      final calls = source.calls.length;

      bloc.add(const ReservationListPageRequested(0));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(source.calls.length, calls);
    });

    test(
      'strana koja je nestala posle osvežavanja: poslednja koja postoji',
      () async {
        await send(bloc, const ReservationListStarted());
        final last = await send(bloc, const ReservationListPageRequested(2));
        expect(ids(last), hasLength(5));

        // Rezervacije sa poslednje strane se otkazuju, pa filter „potvrđene“
        // ima 40 rezervacija i strana 2 više ne postoji.
        await send(
          bloc,
          const ReservationListStatusChanged(ReservationStatus.confirmed),
        );
        final onLast = await send(bloc, const ReservationListPageRequested(2));
        for (final id in ids(onLast)) {
          await store.cancelReservation(ReservationId(id));
        }
        final state = await send(bloc, const ReservationListRefreshed());

        expect((state as ReservationListLoaded).page.total, 40);
        expect(state.query.offset, 20);
        expect(state.page.items, hasLength(20));
      },
    );
  });

  group('zastareli odgovori i odjava', () {
    test('spor odgovor ne prepisuje noviji izbor', () async {
      await send(bloc, const ReservationListStarted());
      final gate = Completer<void>();
      source.gate = gate;

      bloc.add(const ReservationListStatusChanged(ReservationStatus.pending));
      await Future<void>.delayed(Duration.zero);
      final newer = await send(
        bloc,
        const ReservationListStatusChanged(ReservationStatus.completed),
      );
      expect(ids(newer), [4]);

      final states = <ReservationListState>[];
      bloc.stream.listen(states.add);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states, isEmpty);
      expect(bloc.state.query.status, ReservationStatus.completed);
    });

    test('odjava briše podatke i filtere', () async {
      await send(bloc, const ReservationListStarted());
      await send(bloc, const ReservationListSearchChanged('jovan'));

      bloc.add(const ReservationListCleared());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<ReservationListLoading>());
      expect(bloc.state.query, const ReservationQuery());
    });
  });

  group('simulacija izvora', () {
    test('prazan odgovor izvora je prazno stanje', () async {
      store.simulateEmpty = true;

      final state = await send(bloc, const ReservationListStarted());

      expect(state, isA<ReservationListEmpty>());
    });

    test('isti ulaz daje jednako stanje', () async {
      final first = await send(bloc, const ReservationListStarted());
      final second = await send(bloc, const ReservationListRefreshed());

      expect(second, first);
    });
  });
}
