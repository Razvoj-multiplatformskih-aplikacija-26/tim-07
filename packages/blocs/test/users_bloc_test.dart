import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

AppUser person(
  int id,
  String first,
  String last,
  UserRole role, {
  bool isActive = true,
}) => AppUser(
  id: UserId(id),
  firstName: first,
  lastName: last,
  email: '${first.toLowerCase()}@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026, 1, 1),
  isActive: isActive,
);

final admin = person(1, 'Admin', 'Adminović', UserRole.admin);
final owner = person(2, 'Petar', 'Vlasnik', UserRole.owner);
final jovan = person(3, 'Jovan', 'Petrović', UserRole.user);
final ana = person(4, 'Ana', 'Anić', UserRole.user);
final stranger = person(5, 'Đorđe', 'Šarić', UserRole.user);

/// Izvor koji propušta pozive pravom repozitorijumu, broji ih i može da ih odbije.
final class _Source implements UserAdministrationRepository {
  final UserAdministrationRepository inner;
  Object? readError;
  Object? writeError;
  int reads = 0;
  int writes = 0;

  _Source(this.inner);

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    reads++;
    final failure = readError;
    if (failure != null) throw failure;
    return inner.getUsers(role: role);
  }

  @override
  Future<AppUser> setUserActive(UserId id, {required bool active}) async {
    writes++;
    final failure = writeError;
    if (failure != null) throw failure;
    return inner.setUserActive(id, active: active);
  }
}

Future<UsersState> settled(UsersBloc bloc) =>
    bloc.stream.firstWhere((state) => state is! UsersLoading);

Future<UsersLoaded> send(UsersBloc bloc, UsersEvent event) async {
  final next = bloc.stream.first;
  bloc.add(event);
  return await next as UsersLoaded;
}

List<int> ids(UsersLoaded state) => [for (final u in state.visible) u.id.value];

void main() {
  late FakeUserAdministrationRepository store;
  late _Source source;
  late UsersBloc bloc;

  UsersBloc create(AppUser viewer) => UsersBloc(users: source, viewer: viewer);

  setUp(() {
    store = FakeUserAdministrationRepository(
      users: [admin, owner, jovan, ana, stranger],
    );
    source = _Source(store);
    bloc = create(admin);
  });

  tearDown(() => bloc.close());

  group('početak', () {
    test('administrator vidi sve naloge, po prezimenu', () async {
      final next = settled(bloc);
      bloc.add(const UsersStarted());
      final state = await next as UsersLoaded;

      // Adminović, Anić, Petrović, Šarić, Vlasnik.
      expect(ids(state), [1, 4, 3, 5, 2]);
      expect(state.all, hasLength(5));
      expect(state.hasFilters, isFalse);
      expect(state.message, isNull);
    });

    test('vlasnik i korisnik ne dobijaju ništa i ništa ne traže', () async {
      for (final viewer in [owner, jovan]) {
        final restricted = create(viewer);
        addTearDown(restricted.close);

        restricted.add(const UsersStarted());
        await Future<void>.delayed(Duration.zero);

        expect(restricted.state, isA<UsersForbidden>());
      }
      expect(source.reads, 0);
    });

    test('greška izvora je stanje greške sa porukom', () async {
      source.readError = const ServerUnreachableException();

      final next = settled(bloc);
      bloc.add(const UsersStarted());
      final state = await next;

      expect(state, isA<UsersError>());
      expect(
        (state as UsersError).message,
        describeError(const ServerUnreachableException()),
      );
    });

    test('ponovni pokušaj posle greške učitava naloge', () async {
      source.readError = const ServerUnreachableException();
      final failed = settled(bloc);
      bloc.add(const UsersStarted());
      await failed;

      source.readError = null;
      final next = settled(bloc);
      bloc.add(const UsersStarted());

      expect(await next, isA<UsersLoaded>());
    });
  });

  group('pretraga i uloga', () {
    setUp(() async {
      final loaded = settled(bloc);
      bloc.add(const UsersStarted());
      await loaded;
    });

    test('pretraga ne gleda slova ni dijakritike', () async {
      expect(ids(await send(bloc, const UsersSearchChanged('PETROVIC'))), [3]);
      expect(ids(await send(bloc, const UsersSearchChanged('djordje'))), [5]);
    });

    test('pretraga traži i po email-u', () async {
      expect(ids(await send(bloc, const UsersSearchChanged('ana@'))), [4]);
    });

    test('uloga sužava spisak, a „sve“ ga vraća', () async {
      final owners = await send(bloc, const UsersRoleChanged(UserRole.owner));
      expect(ids(owners), [2]);
      expect(owners.hasFilters, isTrue);

      final all = await send(bloc, const UsersRoleChanged(null));
      expect(all.visible, hasLength(5));
      expect(all.hasFilters, isFalse);
    });

    test('pretraga i uloga rade zajedno, bez novog zahteva serveru', () async {
      final reads = source.reads;
      await send(bloc, const UsersRoleChanged(UserRole.user));

      final state = await send(bloc, const UsersSearchChanged('ana'));

      expect(ids(state), [4]);
      expect(source.reads, reads);
    });

    test('pretraga bez rezultata je prazan spisak, ne greška', () async {
      final state = await send(bloc, const UsersSearchChanged('nepostojeci'));

      expect(state.visible, isEmpty);
      expect(state.all, hasLength(5));
    });

    test('ista pretraga ponovo ne menja stanje', () async {
      await send(bloc, const UsersSearchChanged('ana'));
      final states = <UsersState>[];
      bloc.stream.listen(states.add);

      bloc.add(const UsersSearchChanged('ana'));
      bloc.add(const UsersRoleChanged(null));
      await Future<void>.delayed(Duration.zero);

      expect(states, isEmpty);
    });

    test('osvežavanje čuva pretragu i ulogu', () async {
      await send(bloc, const UsersRoleChanged(UserRole.user));
      await send(bloc, const UsersSearchChanged('ana'));

      // Nešto se promenilo na serveru, pa osvežavanje daje drugačije stanje.
      await store.setUserActive(jovan.id, active: false);
      final state = await send(bloc, const UsersRefreshed());

      expect(state.role, UserRole.user);
      expect(state.search, 'ana');
      expect(ids(state), [4]);
    });
  });

  group('deaktivacija', () {
    setUp(() async {
      final loaded = settled(bloc);
      bloc.add(const UsersStarted());
      await loaded;
    });

    test('administrator deaktivira nalog, a spisak to pokazuje', () async {
      final states = <UsersState>[];
      bloc.stream.listen(states.add);

      bloc.add(UserActiveChangeRequested(jovan, active: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect((states.first as UsersLoaded).busy, jovan.id);
      final done = states.last as UsersLoaded;
      expect(done.busy, isNull);
      expect(done.all.firstWhere((u) => u.id == jovan.id).isActive, isFalse);
      expect(done.all.where((u) => u.isActive), hasLength(4));
      expect(source.writes, 1);
    });

    test('nalog može ponovo da se aktivira', () async {
      await store.setUserActive(ana.id, active: false);
      await send(bloc, const UsersRefreshed());

      bloc.add(UserActiveChangeRequested(ana, active: true));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = bloc.state as UsersLoaded;
      expect(state.all.firstWhere((u) => u.id == ana.id).isActive, isTrue);
    });

    test('svoj nalog administrator ne sme da deaktivira', () async {
      final state = await send(
        bloc,
        UserActiveChangeRequested(admin, active: false),
      );

      expect(state.message, errorMessageForForbidden());
      expect(source.writes, 0);
      expect(state.all.firstWhere((u) => u.id == admin.id).isActive, isTrue);
    });

    test('greška servera: razlog i ponovo učitan spisak', () async {
      source.writeError = const ServerUnreachableException();
      final reads = source.reads;

      bloc.add(UserActiveChangeRequested(jovan, active: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = bloc.state as UsersLoaded;
      expect(state.message, describeError(const ServerUnreachableException()));
      expect(state.busy, isNull);
      expect(state.all.firstWhere((u) => u.id == jovan.id).isActive, isTrue);
      expect(source.reads, reads + 1);
    });

    test('nepostojeći nalog: poruka da nije pronađen', () async {
      final ghost = person(99, 'Duh', 'Duhić', UserRole.user);

      bloc.add(UserActiveChangeRequested(ghost, active: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        (bloc.state as UsersLoaded).message,
        describeError(EntityNotFound('user', 99)),
      );
    });

    test('pretraga i uloga ostaju posle izmene', () async {
      await send(bloc, const UsersSearchChanged('petrović'));

      bloc.add(UserActiveChangeRequested(jovan, active: false));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = bloc.state as UsersLoaded;
      expect(state.search, 'petrović');
      expect(ids(state), [3]);
    });

    test('vlasnik ne može da menja naloge ni preko događaja', () async {
      // Stanje „zabranjeno“ nikad ne postaje „učitano“, pa izmena nema šta da menja.
      final restricted = create(owner);
      addTearDown(restricted.close);

      restricted.add(UserActiveChangeRequested(jovan, active: false));
      await Future<void>.delayed(Duration.zero);

      expect(restricted.state, isA<UsersForbidden>());
      expect(source.writes, 0);
    });
  });
}

String errorMessageForForbidden() => 'Nemate pravo na ovu radnju.';
