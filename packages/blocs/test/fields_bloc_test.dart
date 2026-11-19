import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

SportsField field(
  int id,
  String name,
  SportType sport,
  int price, {
  bool isActive = true,
  ApprovalStatus approval = ApprovalStatus.approved,
}) => SportsField(
  id: FieldId(id),
  ownerId: const UserId(100),
  name: name,
  description: 'Opis $name',
  sport: sport,
  address: 'Adresa $id',
  city: 'Beograd',
  pricePerHour: price,
  contactPhone: '0601234567',
  confirmationMode: ConfirmationMode.manual,
  isActive: isActive,
  approvalStatus: approval,
);

final arena = field(1, 'Arena Fudbal', SportType.football, 3500);
final basket = field(2, 'Basket Centar', SportType.basketball, 2000);
final tennis = field(3, 'Tennis Club', SportType.tennis, 2500);
final padel = field(4, 'Padel Arena', SportType.padel, 3000);
final tenis2 = field(5, 'Tenis Akademija', SportType.tennis, 2500);

/// Izvor koji odbija poziv zadatom greškom, ili čeka dok test ne dozvoli.
final class _ControlledRepository implements SportsFieldRepository {
  final SportsFieldRepository inner;
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  _ControlledRepository(this.inner);

  // Ishod se određuje u trenutku poziva, a stiže tek kada se otvori kapija:
  // tako zahtev koji kasni nosi staru grešku ili stare terene.
  @override
  Future<List<SportsField>> getPublicFields() async {
    calls++;
    final failure = error;
    final wait = gate;
    final result = failure == null ? await inner.getPublicFields() : null;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
    return result!;
  }

  @override
  Future<SportsField?> getFieldById(FieldId id) async {
    final failure = error;
    if (failure != null) throw failure;
    return inner.getFieldById(id);
  }

  @override
  Future<List<SportsField>> getFields() => inner.getFields();

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) =>
      inner.getFieldsByOwner(ownerId);

  @override
  Future<SportsField> createField({
    required UserId ownerId,
    required String name,
    required String description,
    required SportType sport,
    required String address,
    required String city,
    required int pricePerHour,
    required String contactPhone,
    List<String> imageUrls = const [],
    required ConfirmationMode confirmationMode,
  }) => inner.createField(
    ownerId: ownerId,
    name: name,
    description: description,
    sport: sport,
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
    imageUrls: imageUrls,
    confirmationMode: confirmationMode,
  );

  @override
  Future<SportsField> updateField(SportsField field) =>
      inner.updateField(field);

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() =>
      inner.getFieldsAwaitingApproval();

  @override
  Future<SportsField> reviewField({
    required FieldId fieldId,
    required UserId reviewerId,
    required ApprovalStatus decision,
    String? reason,
  }) => inner.reviewField(
    fieldId: fieldId,
    reviewerId: reviewerId,
    decision: decision,
    reason: reason,
  );
}

List<String> names(Iterable<SportsField> fields) => [
  for (final f in fields) f.name,
];

void main() {
  late FakeSportsFieldRepository store;
  late _ControlledRepository source;

  setUp(() {
    store = FakeSportsFieldRepository(
      fields: [arena, basket, tennis, padel, tenis2],
    );
    source = _ControlledRepository(store);
  });

  Future<FieldsBloc> loaded() async {
    final bloc = FieldsBloc(repository: source)..add(const FieldsRequested());
    await bloc.stream.firstWhere((s) => s is FieldsLoaded);
    return bloc;
  }

  group('filteri (čista funkcija)', () {
    final all = [arena, basket, tennis, padel, tenis2];

    test('bez filtera su svi tereni, istim redom', () {
      expect(applyFieldFilters(all, const FieldFilters()), all);
    });

    test('pretraga traži deo naziva, bez obzira na velika slova', () {
      expect(
        names(applyFieldFilters(all, const FieldFilters(query: 'ARENA'))),
        ['Arena Fudbal', 'Padel Arena'],
      );
      expect(
        names(applyFieldFilters(all, const FieldFilters(query: '  tenn '))),
        ['Tennis Club'],
      );
    });

    test('sport izdvaja samo terene tog sporta', () {
      expect(
        names(
          applyFieldFilters(all, const FieldFilters(sport: SportType.tennis)),
        ),
        ['Tennis Club', 'Tenis Akademija'],
      );
    });

    test('pretraga i sport rade zajedno', () {
      final filters = const FieldFilters(
        query: 'club',
        sport: SportType.tennis,
      );

      expect(names(applyFieldFilters(all, filters)), ['Tennis Club']);
      expect(
        applyFieldFilters(
          all,
          const FieldFilters(query: 'club', sport: SportType.football),
        ),
        isEmpty,
      );
    });

    test('redosled po ceni, a iste cene ostaju redom kojim su stigle', () {
      expect(
        names(
          applyFieldFilters(
            all,
            const FieldFilters(sort: FieldSort.priceAscending),
          ),
        ),
        [
          'Basket Centar',
          'Tennis Club',
          'Tenis Akademija',
          'Padel Arena',
          'Arena Fudbal',
        ],
      );
      expect(
        names(
          applyFieldFilters(
            all,
            const FieldFilters(sort: FieldSort.priceDescending),
          ),
        ),
        [
          'Arena Fudbal',
          'Padel Arena',
          'Tennis Club',
          'Tenis Akademija',
          'Basket Centar',
        ],
      );
    });

    test('ulazna lista se ne menja', () {
      final before = List.of(all);

      applyFieldFilters(
        all,
        const FieldFilters(sort: FieldSort.priceAscending),
      );

      expect(all, before);
    });

    test('podrazumevani filteri se prepoznaju', () {
      expect(const FieldFilters().isDefault, isTrue);
      expect(const FieldFilters(query: '   ').isDefault, isTrue);
      expect(const FieldFilters(query: 'a').isDefault, isFalse);
      expect(const FieldFilters(sport: SportType.padel).isDefault, isFalse);
      expect(
        const FieldFilters(sort: FieldSort.priceAscending).isDefault,
        isFalse,
      );
    });

    test('sport se vraća na „svi“ samo izričito', () {
      const filters = FieldFilters(sport: SportType.padel);

      expect(filters.copyWith(query: 'a').sport, SportType.padel);
      expect(filters.copyWith(clearSport: true).sport, isNull);
    });
  });

  group('FieldsBloc: učitavanje', () {
    test('početno stanje je Initial', () async {
      final bloc = FieldsBloc(repository: source);

      expect(bloc.state, const FieldsInitial());
      await bloc.close();
    });

    test('Loading, pa Loaded sa javnim terenima', () async {
      final bloc = FieldsBloc(repository: source)..add(const FieldsRequested());

      final states = await bloc.stream.take(2).toList();

      expect(states[0], isA<FieldsLoading>());
      expect(states[1], isA<FieldsLoaded>());
      expect(
        names(states[1].fields),
        names([arena, basket, tennis, padel, tenis2]),
      );
      await bloc.close();
    });

    test('u katalogu su samo aktivni i odobreni tereni', () async {
      store = FakeSportsFieldRepository(
        fields: [
          arena,
          field(
            6,
            'Čeka odobrenje',
            SportType.football,
            1000,
            approval: ApprovalStatus.pending,
          ),
          field(
            7,
            'Odbijen',
            SportType.football,
            1000,
            approval: ApprovalStatus.rejected,
          ),
          field(8, 'Neaktivan', SportType.football, 1000, isActive: false),
        ],
      );
      source = _ControlledRepository(store);

      final bloc = await loaded();

      expect(names(bloc.state.fields), ['Arena Fudbal']);
      await bloc.close();
    });

    test('izvor bez terena daje Empty, ne Loaded sa praznom listom', () async {
      source = _ControlledRepository(FakeSportsFieldRepository());
      final bloc = FieldsBloc(repository: source)..add(const FieldsRequested());

      final states = await bloc.stream.take(2).toList();

      expect(states[1], isA<FieldsEmpty>());
      await bloc.close();
    });

    test('greška servera: poruka za korisnika, bez tehničkog teksta', () async {
      source.error = const ServerRejectedException(
        ErrorDto(code: 'court_closed_for_holiday'),
      );
      final bloc = FieldsBloc(repository: source)..add(const FieldsRequested());

      final states = await bloc.stream.take(2).toList();

      expect(states[1], isA<FieldsError>());
      expect((states[1] as FieldsError).message, genericErrorMessage);
      await bloc.close();
    });

    test(
      'nema mreže: poruka o nedostupnom serveru, pa „pokušaj ponovo“ radi',
      () async {
        source.error = const ServerUnreachableException();
        final bloc = FieldsBloc(repository: source)
          ..add(const FieldsRequested());
        await bloc.stream.firstWhere((s) => s is FieldsError);

        expect((bloc.state as FieldsError).message, serverUnreachableMessage);

        source.error = null;
        bloc.add(const FieldsRequested());
        await bloc.stream.firstWhere((s) => s is FieldsLoaded);

        expect(bloc.state.fields, hasLength(5));
        await bloc.close();
      },
    );

    test('odgovor starijeg zahteva ne prepisuje noviji', () async {
      final bloc = FieldsBloc(repository: source);
      final gate = Completer<void>();

      // Prvi zahtev će pasti, ali njegov odgovor kasni.
      source
        ..error = const ServerUnreachableException()
        ..gate = gate;
      bloc.add(const FieldsRequested());
      await pumpEventQueue();

      // Drugi zahtev uspeva i stiže prvi.
      source
        ..error = null
        ..gate = null;
      bloc.add(const FieldsRequested());
      await bloc.stream.firstWhere((s) => s is FieldsLoaded);

      // Tek sada stiže zakasneli neuspeh prvog zahteva.
      gate.complete();
      await pumpEventQueue();

      expect(bloc.state, isA<FieldsLoaded>());
      expect(source.calls, 2);
      await bloc.close();
    });
  });
  group('FieldsBloc: pretraga, sport i redosled', () {
    test('pretraga sužava listu bez novog zahteva', () async {
      final bloc = await loaded();
      final calls = source.calls;

      bloc.add(const FieldsSearchChanged('arena'));
      await pumpEventQueue();

      final state = bloc.state as FieldsLoaded;
      expect(names(state.visible), ['Arena Fudbal', 'Padel Arena']);
      expect(state.fields, hasLength(5));
      expect(state.filters.query, 'arena');
      expect(source.calls, calls);
      await bloc.close();
    });

    test('izbor sporta i povratak na „svi“', () async {
      final bloc = await loaded();

      bloc.add(const FieldsSportSelected(SportType.tennis));
      await pumpEventQueue();
      expect(names((bloc.state as FieldsLoaded).visible), [
        'Tennis Club',
        'Tenis Akademija',
      ]);

      bloc.add(const FieldsSportSelected(null));
      await pumpEventQueue();
      expect((bloc.state as FieldsLoaded).visible, hasLength(5));
      expect(bloc.state.filters.sport, isNull);
      await bloc.close();
    });

    test('redosled po ceni', () async {
      final bloc = await loaded();

      bloc.add(const FieldsSortChanged(FieldSort.priceAscending));
      await pumpEventQueue();

      expect((bloc.state as FieldsLoaded).visible.first.name, 'Basket Centar');
      await bloc.close();
    });

    test(
      'filteri bez rezultata daju Loaded sa praznom listom, ne Empty',
      () async {
        final bloc = await loaded();

        bloc.add(const FieldsSearchChanged('nema takvog'));
        await pumpEventQueue();

        expect(bloc.state, isA<FieldsLoaded>());
        expect((bloc.state as FieldsLoaded).visible, isEmpty);
        expect(bloc.state.fields, hasLength(5));
        await bloc.close();
      },
    );

    test('reset vraća sve filtere', () async {
      final bloc = await loaded();
      bloc
        ..add(const FieldsSearchChanged('arena'))
        ..add(const FieldsSportSelected(SportType.padel))
        ..add(const FieldsSortChanged(FieldSort.priceDescending));
      await pumpEventQueue();

      bloc.add(const FieldsFiltersReset());
      await pumpEventQueue();

      expect(bloc.state.filters, const FieldFilters());
      expect((bloc.state as FieldsLoaded).visible, hasLength(5));
      await bloc.close();
    });

    test('osvežavanje čuva filtere', () async {
      final bloc = await loaded();
      bloc.add(const FieldsSportSelected(SportType.tennis));
      await pumpEventQueue();

      bloc.add(const FieldsRequested());
      await bloc.stream.firstWhere((s) => s is FieldsLoaded);

      expect(bloc.state.filters.sport, SportType.tennis);
      expect(names((bloc.state as FieldsLoaded).visible), [
        'Tennis Club',
        'Tenis Akademija',
      ]);
      await bloc.close();
    });

    test(
      'filteri zadati pre učitavanja se primenjuju čim stignu tereni',
      () async {
        final bloc = FieldsBloc(repository: source)
          ..add(const FieldsSearchChanged('padel'))
          ..add(const FieldsRequested());

        await bloc.stream.firstWhere((s) => s is FieldsLoaded);

        expect(names((bloc.state as FieldsLoaded).visible), ['Padel Arena']);
        await bloc.close();
      },
    );

    test('filteri se vide i u stanju učitavanja i greške', () async {
      source.error = const ServerUnreachableException();
      final bloc = FieldsBloc(repository: source)
        ..add(const FieldsSortChanged(FieldSort.priceAscending))
        ..add(const FieldsRequested());

      await bloc.stream.firstWhere((s) => s is FieldsError);

      expect(bloc.state.filters.sort, FieldSort.priceAscending);
      await bloc.close();
    });
  });

  group('FieldDetailsBloc', () {
    test('Loading, pa Loaded', () async {
      final bloc = FieldDetailsBloc(repository: source)
        ..add(const FieldDetailsRequested(FieldId(3)));

      final state = await bloc.stream.firstWhere(
        (s) => s is FieldDetailsLoaded,
      );

      expect((state as FieldDetailsLoaded).field.name, 'Tennis Club');
      await bloc.close();
    });

    test('nepostojeći teren je NotFound', () async {
      final bloc = FieldDetailsBloc(repository: source)
        ..add(const FieldDetailsRequested(FieldId(999)));

      await bloc.stream.firstWhere((s) => s is FieldDetailsNotFound);
      await bloc.close();
    });

    test('teren koji nije javan se ne vidi ni preko adrese', () async {
      store = FakeSportsFieldRepository(
        fields: [
          field(
            6,
            'Čeka odobrenje',
            SportType.football,
            1000,
            approval: ApprovalStatus.pending,
          ),
        ],
      );
      source = _ControlledRepository(store);
      final bloc = FieldDetailsBloc(repository: source)
        ..add(const FieldDetailsRequested(FieldId(6)));

      await bloc.stream.firstWhere((s) => s is FieldDetailsNotFound);
      await bloc.close();
    });

    test(
      'greška izvora: poruka za korisnika, pa ponovni pokušaj radi',
      () async {
        source.error = const ServerUnreachableException();
        final bloc = FieldDetailsBloc(repository: source)
          ..add(const FieldDetailsRequested(FieldId(1)));

        final error = await bloc.stream.firstWhere(
          (s) => s is FieldDetailsError,
        );
        expect((error as FieldDetailsError).message, serverUnreachableMessage);

        source.error = null;
        bloc.add(const FieldDetailsRequested(FieldId(1)));
        await bloc.stream.firstWhere((s) => s is FieldDetailsLoaded);
        await bloc.close();
      },
    );
  });

  group('FakeSportsFieldRepository', () {
    test(
      'nov teren dobija sledeći id i čeka odobrenje, pa nije javan',
      () async {
        final created = await store.createField(
          ownerId: const UserId(100),
          name: 'Novi',
          description: 'Opis',
          sport: SportType.padel,
          address: 'A 1',
          city: 'Beograd',
          pricePerHour: 2800,
          contactPhone: '060',
          confirmationMode: ConfirmationMode.automatic,
        );

        expect(created.id, const FieldId(6));
        expect(created.approvalStatus, ApprovalStatus.pending);
        expect(await store.getFieldsAwaitingApproval(), [created]);
        expect(names(await store.getPublicFields()), isNot(contains('Novi')));
      },
    );

    test('administrator odobrava, pa teren postaje javan', () async {
      final created = await store.createField(
        ownerId: const UserId(100),
        name: 'Novi',
        description: 'Opis',
        sport: SportType.padel,
        address: 'A 1',
        city: 'Beograd',
        pricePerHour: 2800,
        contactPhone: '060',
        confirmationMode: ConfirmationMode.automatic,
      );

      final approved = await store.reviewField(
        fieldId: created.id,
        reviewerId: const UserId(1),
        decision: ApprovalStatus.approved,
      );

      expect(approved.approvalStatus, ApprovalStatus.approved);
      expect(names(await store.getPublicFields()), contains('Novi'));
      expect(await store.getFieldsAwaitingApproval(), isEmpty);
    });

    test(
      'odbijanje čuva razlog, a izmena vlasnika vraća teren na čekanje',
      () async {
        final created = await store.createField(
          ownerId: const UserId(100),
          name: 'Novi',
          description: 'Opis',
          sport: SportType.padel,
          address: 'A 1',
          city: 'Beograd',
          pricePerHour: 2800,
          contactPhone: '060',
          confirmationMode: ConfirmationMode.automatic,
        );
        final rejected = await store.reviewField(
          fieldId: created.id,
          reviewerId: const UserId(1),
          decision: ApprovalStatus.rejected,
          reason: 'Nedostaju slike',
        );
        expect(rejected.rejectionReason, 'Nedostaju slike');

        final edited = await store.updateField(
          rejected.copyWith(name: 'Novi 2'),
        );

        expect(edited.name, 'Novi 2');
        expect(edited.approvalStatus, ApprovalStatus.pending);
      },
    );

    test(
      'izmena ne može da sama odobri teren ni da promeni vlasnika',
      () async {
        final edited = await store.updateField(
          field(
            1,
            'Arena Fudbal',
            SportType.football,
            3900,
          ).copyWith(approvalStatus: ApprovalStatus.approved),
        );

        expect(edited.pricePerHour, 3900);
        expect(edited.ownerId, arena.ownerId);
      },
    );

    test('nedozvoljen prelaz odobrenosti baca izuzetak', () async {
      await expectLater(
        store.reviewField(
          fieldId: const FieldId(1),
          reviewerId: const UserId(1),
          decision: ApprovalStatus.pending,
        ),
        throwsA(isA<ApprovalTransitionNotAllowed>()),
      );
    });

    test('nepostojeći teren baca EntityNotFound', () async {
      await expectLater(
        store.reviewField(
          fieldId: const FieldId(999),
          reviewerId: const UserId(1),
          decision: ApprovalStatus.approved,
        ),
        throwsA(isA<EntityNotFound>()),
      );
      await expectLater(
        store.updateField(field(999, 'X', SportType.other, 1)),
        throwsA(isA<EntityNotFound>()),
      );
    });

    test('tereni jednog vlasnika', () async {
      expect(await store.getFieldsByOwner(const UserId(100)), hasLength(5));
      expect(await store.getFieldsByOwner(const UserId(7)), isEmpty);
    });
  });
}
