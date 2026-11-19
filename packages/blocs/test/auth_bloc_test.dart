import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

AppUser person(int id, UserRole role, String email) => AppUser(
  id: UserId(id),
  firstName: 'Ime$id',
  lastName: 'Prezime$id',
  email: email,
  phoneNumber: '064000000$id',
  dateOfBirth: DateTime(1999, 1, 1),
  role: role,
  createdAt: DateTime(2026, 1, 1),
);

final ana = person(1, UserRole.user, 'ana@example.com');
final vlasnik = person(10, UserRole.owner, 'vlasnik@example.com');
final admin = person(99, UserRole.admin, 'admin@example.com');

final accounts = [
  FakeAccount(user: ana, password: 'ana-lozinka'),
  FakeAccount(user: vlasnik, password: 'vlasnik-lozinka'),
  FakeAccount(user: admin, password: 'admin-lozinka'),
];

final now = DateTime.utc(2026, 11, 18, 12);

FakeAuthRepository repositoryAt(
  DateTime Function() clock, {
  Duration delay = Duration.zero,
}) => FakeAuthRepository(accounts: accounts, clock: clock, delay: delay);

/// Šalje događaje redom i vraća sva stanja koja je Bloc emitovao.
Future<List<AuthState>> run(AuthBloc bloc, List<AuthEvent> events) async {
  final states = <AuthState>[];
  final subscription = bloc.stream.listen(states.add);

  for (final event in events) {
    bloc.add(event);
    await pumpEventQueue();
  }

  await subscription.cancel();
  return states;
}

AuthLoginRequested login(String email, String password) =>
    AuthLoginRequested(email: email, password: password);

void main() {
  late FakeAuthRepository repository;
  late DateTime Function() clock;
  late DateTime current;

  setUp(() {
    current = now;
    clock = () => current;
    repository = repositoryAt(clock);
  });

  group('pokretanje', () {
    test('početno stanje je nepoznato', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      expect(bloc.state, const AuthUnknown());
      expect(bloc.state.user, isNull);

      await bloc.close();
    });

    test('bez sačuvane prijave korisnik nije prijavljen', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [const AuthStarted()]);

      expect(states, [const AuthUnauthenticated()]);
      await bloc.close();
    });

    test('prijava preživljava ponovno pokretanje aplikacije', () async {
      final first = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(first, [login('ana@example.com', 'ana-lozinka')]);
      await first.close();

      // Nova aplikacija, isti sačuvani token.
      final second = AuthBloc(repository: repository, app: ClientApp.mobile);
      final states = await run(second, [const AuthStarted()]);

      expect(states, hasLength(1));
      expect(states.single, isA<AuthAuthenticated>());
      expect(second.state.user!.id, ana.id);
      await second.close();
    });

    test('istekla sačuvana prijava se ne vraća', () async {
      final first = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(first, [login('ana@example.com', 'ana-lozinka')]);
      await first.close();

      current = now.add(const Duration(hours: 9));
      final second = AuthBloc(repository: repository, app: ClientApp.mobile);
      final states = await run(second, [const AuthStarted()]);

      expect(states, [const AuthUnauthenticated()]);
      await second.close();
    });

    test('server nije dostupan: prijava ostaje sačuvana, pa „pokušaj ponovo“ radi', () async {
      final first = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(first, [login('ana@example.com', 'ana-lozinka')]);
      await first.close();

      repository.simulateUnreachable = true;
      final second = AuthBloc(repository: repository, app: ClientApp.mobile);
      final offline = await run(second, [const AuthStarted()]);

      expect(offline, [
        const AuthUnauthenticated(
          reason: SignOutReason.unavailable,
          message: serverUnreachableMessage,
        ),
      ]);
      expect(repository.stored, isNotNull);

      repository.simulateUnreachable = false;
      final retried = await run(second, [const AuthStarted()]);

      expect(retried.last, isA<AuthAuthenticated>());
      expect(second.state.user!.id, ana.id);
      await second.close();
    });

    test('sačuvana prijava naloga koji nije za ovu aplikaciju se briše', () async {
      final mobile = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(mobile, [login('ana@example.com', 'ana-lozinka')]);
      await mobile.close();

      final backoffice = AuthBloc(
        repository: repository,
        app: ClientApp.backoffice,
      );
      final states = await run(backoffice, [const AuthStarted()]);

      expect(states.single, isA<AuthUnauthenticated>());
      expect(
        (states.single as AuthUnauthenticated).reason,
        SignOutReason.roleNotAllowed,
      );
      expect(repository.stored, isNull);
      await backoffice.close();
    });
  });

  group('prijava', () {
    test('uspešna prijava daje prijavljenog korisnika iz stanja', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [login(' Ana@Example.com ', 'ana-lozinka')]);

      expect(states.first, const AuthSigningIn());
      final signedIn = states.last as AuthAuthenticated;
      expect(signedIn.user.id, ana.id);
      expect(signedIn.expiresAt, now.add(const Duration(hours: 8)));
      // Ekrani čitaju korisnika odavde, ne iz demo podataka.
      expect(bloc.state.user!.fullName, 'Ime1 Prezime1');
      await bloc.close();
    });

    test('pogrešna lozinka i nepostojeći e-mail daju istu poruku', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final wrongPassword = await run(bloc, [login('ana@example.com', 'x')]);
      final unknownEmail = await run(bloc, [login('niko@example.com', 'x')]);

      const expected = AuthFailed('Pogrešan e-mail ili lozinka.');
      expect(wrongPassword, [const AuthSigningIn(), expected]);
      expect(unknownEmail, [const AuthSigningIn(), expected]);
      expect(repository.stored, isNull);
      await bloc.close();
    });

    test('prazna polja ne zovu server', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [
        login('', 'ana-lozinka'),
        login('ana@example.com', ''),
        login('   ', '   '),
      ]);

      expect(states, [const AuthFailed(credentialsRequiredMessage)]);
      expect(repository.stored, isNull);
      await bloc.close();
    });

    test('nema mreže: poruka za korisnika, bez tehničkog teksta', () async {
      repository.simulateUnreachable = true;
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [login('ana@example.com', 'ana-lozinka')]);

      expect(states.last, const AuthFailed('Server trenutno nije dostupan.'));
      await bloc.close();
    });

    test('dvostruki klik šalje jedan zahtev', () async {
      final slow = repositoryAt(clock, delay: const Duration(milliseconds: 30));
      final bloc = AuthBloc(repository: slow, app: ClientApp.mobile);
      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc
        ..add(login('ana@example.com', 'ana-lozinka'))
        ..add(login('ana@example.com', 'ana-lozinka'));
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(states.whereType<AuthSigningIn>(), hasLength(1));
      expect(states.whereType<AuthAuthenticated>(), hasLength(1));

      await subscription.cancel();
      await bloc.close();
    });

    test('posle greške može da se proba ponovo', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [
        login('ana@example.com', 'pogresna'),
        login('ana@example.com', 'ana-lozinka'),
      ]);

      expect(states.whereType<AuthFailed>(), hasLength(1));
      expect(states.last, isA<AuthAuthenticated>());
      await bloc.close();
    });
  });

  group('ko sme u koju aplikaciju', () {
    test('backoffice odbija korisnika mobilne aplikacije i kaže zašto', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.backoffice);

      final states = await run(bloc, [login('ana@example.com', 'ana-lozinka')]);

      expect(states, [
        const AuthSigningIn(),
        AuthUnauthenticated(
          reason: SignOutReason.roleNotAllowed,
          message: signInNotAllowedMessage(ClientApp.backoffice),
        ),
      ]);
      expect(
        bloc.state.message,
        'Pristup odbijen.',
      );
      // Odbijena prijava ne ostaje sačuvana.
      expect(repository.stored, isNull);
      await bloc.close();
    });

    test('mobilna aplikacija odbija vlasnika', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [
        login('vlasnik@example.com', 'vlasnik-lozinka'),
      ]);

      expect(states.last, isA<AuthUnauthenticated>());
      expect(
        (states.last as AuthUnauthenticated).reason,
        SignOutReason.roleNotAllowed,
      );
      expect(bloc.state.user, isNull);
      expect(repository.stored, isNull);
      await bloc.close();
    });

    test('backoffice prima vlasnika i administratora', () async {
      for (final entry in {
        'vlasnik@example.com': 'vlasnik-lozinka',
        'admin@example.com': 'admin-lozinka',
      }.entries) {
        final bloc = AuthBloc(
          repository: repository,
          app: ClientApp.backoffice,
        );

        await run(bloc, [login(entry.key, entry.value)]);

        expect(bloc.state, isA<AuthAuthenticated>(), reason: entry.key);
        await bloc.close();
      }
    });
  });

  group('odjava i istek', () {
    test('odjava briše prijavu', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      final states = await run(bloc, [
        login('ana@example.com', 'ana-lozinka'),
        const AuthLogoutRequested(),
      ]);

      expect(states.last, const AuthUnauthenticated(reason: SignOutReason.loggedOut));
      expect(bloc.state.user, isNull);
      expect(repository.stored, isNull);

      // Ni ponovno pokretanje je ne vraća.
      final restarted = AuthBloc(repository: repository, app: ClientApp.mobile);
      expect(await run(restarted, [const AuthStarted()]), [
        const AuthUnauthenticated(),
      ]);

      await restarted.close();
      await bloc.close();
    });

    test('istekla prijava: aplikacija to kaže i vraća na prijavu', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(bloc, [login('ana@example.com', 'ana-lozinka')]);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);
      repository.expire();
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, [
        const AuthUnauthenticated(
          reason: SignOutReason.expired,
          message: sessionExpiredMessage,
        ),
      ]);
      expect(bloc.state.message, 'Prijava je istekla. Prijavite se ponovo.');

      // Nova prijava posle isteka radi.
      await run(bloc, [login('ana@example.com', 'ana-lozinka')]);
      expect(bloc.state, isA<AuthAuthenticated>());
      await bloc.close();
    });

    test('istek kada niko nije prijavljen se ignoriše', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);
      await run(bloc, [const AuthStarted()]);

      final states = <AuthState>[];
      final subscription = bloc.stream.listen(states.add);
      repository.expire();
      await pumpEventQueue();
      await subscription.cancel();

      expect(states, isEmpty);
      expect(bloc.state, const AuthUnauthenticated());
      await bloc.close();
    });

    test('posle zatvaranja Bloc-a istek ne pravi grešku', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);
      await bloc.close();

      repository.expire();
      await pumpEventQueue();
    });
  });

  group('stanja i događaji', () {
    test('isti korisnik i isti rok su isto stanje', () {
      final expires = now.add(const Duration(hours: 8));

      expect(
        AuthAuthenticated(user: ana, expiresAt: expires),
        AuthAuthenticated(user: ana, expiresAt: expires),
      );
      expect(
        AuthAuthenticated(user: ana, expiresAt: expires),
        isNot(AuthAuthenticated(user: vlasnik, expiresAt: expires)),
      );
      expect(
        const AuthUnauthenticated(reason: SignOutReason.expired),
        isNot(const AuthUnauthenticated(reason: SignOutReason.loggedOut)),
      );
      expect(const AuthFailed('a'), const AuthFailed('a'));
      expect(const AuthFailed('a'), isNot(const AuthFailed('b')));
    });

    test('lozinka nije deo događaja prijave', () {
      expect(
        login('ana@example.com', 'jedna'),
        login('ana@example.com', 'druga'),
      );
      expect(login('ana@example.com', 'jedna').props, ['ana@example.com']);
    });

    test('poruka nepoznatog koda ne dolazi do korisnika kao tehnički tekst', () async {
      final bloc = AuthBloc(repository: repository, app: ClientApp.mobile);

      await run(bloc, [login('ana@example.com', 'x')]);

      expect(bloc.state.message, isNot(contains('invalid_credentials')));
      await bloc.close();
    });
  });
}
