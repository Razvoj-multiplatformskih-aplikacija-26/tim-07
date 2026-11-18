import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:session_storage/session_storage.dart';

/// Skladište koje ne radi, kao Keystore posle povraćaja iz rezervne kopije.
final class BrokenStorage implements KeyValueStorage {
  final bool failRead;
  final bool failWrite;
  final bool failDelete;
  final MemoryKeyValueStorage inner = MemoryKeyValueStorage();
  int deletes = 0;

  BrokenStorage({
    this.failRead = false,
    this.failWrite = false,
    this.failDelete = false,
  });

  @override
  Future<String?> read(String key) async =>
      failRead ? throw StateError('Keystore je oštećen') : inner.read(key);

  @override
  Future<void> write(String key, String value) async =>
      failWrite ? throw StateError('nema mesta') : inner.write(key, value);

  @override
  Future<void> delete(String key) async {
    deletes++;
    if (failDelete) throw StateError('nema pristupa');
    await inner.delete(key);
  }
}

void main() {
  group('KeyValueSessionStore', () {
    test('bez sačuvane prijave nema tokena', () async {
      final store = KeyValueSessionStore(MemoryKeyValueStorage());

      expect(await store.read(), isNull);
    });

    test('token se čuva i čita', () async {
      final store = KeyValueSessionStore(MemoryKeyValueStorage());

      await store.write('abc.def.ghi');

      expect(await store.read(), 'abc.def.ghi');
    });

    test('novi token zamenjuje stari', () async {
      final store = KeyValueSessionStore(MemoryKeyValueStorage());

      await store.write('prvi');
      await store.write('drugi');

      expect(await store.read(), 'drugi');
    });

    test('odjava briše token', () async {
      final store = KeyValueSessionStore(MemoryKeyValueStorage());
      await store.write('abc');

      await store.clear();

      expect(await store.read(), isNull);
    });

    test(
      'prijava preživljava ponovno pokretanje (novi objekat, isto skladište)',
      () async {
        final storage = MemoryKeyValueStorage();
        await KeyValueSessionStore(storage).write('abc');

        // Nova aplikacija nad istim skladištem uređaja.
        final restarted = KeyValueSessionStore(storage);

        expect(await restarted.read(), 'abc');
      },
    );

    test('čuva se pod jednim ključem i ne dira tuđe zapise', () async {
      final storage = MemoryKeyValueStorage();
      await storage.write('nesto_drugo', 'ostaje');
      final store = KeyValueSessionStore(storage);

      await store.write('abc');
      await store.clear();

      expect(KeyValueSessionStore.defaultKey, 'terenzo_session');
      expect(await storage.read('nesto_drugo'), 'ostaje');
      expect(await storage.read(KeyValueSessionStore.defaultKey), isNull);
    });

    test('prazan zapis nije prijava', () async {
      final storage = MemoryKeyValueStorage();
      await storage.write(KeyValueSessionStore.defaultKey, '');

      expect(await KeyValueSessionStore(storage).read(), isNull);
    });

    test(
      'nečitljiv zapis: korisnik se prijavljuje ponovo, zapis se briše',
      () async {
        final storage = BrokenStorage(failRead: true);

        expect(await KeyValueSessionStore(storage).read(), isNull);
        expect(storage.deletes, 1);
      },
    );

    test('upis koji ne uspe ne ruši prijavu', () async {
      final store = KeyValueSessionStore(BrokenStorage(failWrite: true));

      await store.write('abc');

      expect(await store.read(), isNull);
    });

    test('odjava ne puca ni kada brisanje ne uspe', () async {
      final store = KeyValueSessionStore(BrokenStorage(failDelete: true));

      await store.clear();
    });
  });

  group('sa ApiClient-om', () {
    http.Response json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json'},
    );

    final user = {
      'id': 2,
      'firstName': 'Ana',
      'lastName': 'Jovanović',
      'email': 'ana@example.com',
      'role': 'user',
    };

    ApiClient clientOver(KeyValueStorage storage, MockClient server) =>
        ApiClient(
          baseUri: Uri.parse('http://localhost:8080'),
          session: KeyValueSessionStore(storage),
          httpClient: server,
        );

    test(
      'prijava ostaje posle ponovnog pokretanja, a lozinka se ne čuva',
      () async {
        final storage = MemoryKeyValueStorage();
        String? tokenSentOnRestore;
        final server = MockClient((request) async {
          if (request.url.path == ApiPaths.login) {
            return json(200, {
              'token': 'jwt-token',
              'expiresAt': '2026-11-18T20:00:00.000Z',
              'user': user,
            });
          }
          tokenSentOnRestore = request.headers['authorization'];
          return json(200, {
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': user,
          });
        });

        await HttpSessionRepository(
          clientOver(storage, server),
        ).logIn(email: 'ana@example.com', password: 'tajna-lozinka');

        // Ponovno pokretanje: nov ApiClient, isto skladište.
        final restored = await HttpSessionRepository(
          clientOver(storage, server),
        ).restore();

        expect(restored!.user.role, UserRole.user);
        expect(tokenSentOnRestore, 'Bearer jwt-token');
        expect(
          await storage.read(KeyValueSessionStore.defaultKey),
          'jwt-token',
        );
        expect(
          await storage.read(KeyValueSessionStore.defaultKey),
          isNot(contains('tajna-lozinka')),
        );
      },
    );

    test('posle odjave nema prijave ni posle ponovnog pokretanja', () async {
      final storage = MemoryKeyValueStorage();
      await KeyValueSessionStore(storage).write('jwt-token');
      var calls = 0;
      final server = MockClient((request) async {
        calls++;
        return json(200, {});
      });

      await HttpSessionRepository(clientOver(storage, server)).logOut();

      final restored = await HttpSessionRepository(
        clientOver(storage, server),
      ).restore();

      expect(restored, isNull);
      expect(calls, 0);
    });
  });
}
