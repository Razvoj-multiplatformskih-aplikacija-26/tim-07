@TestOn('browser')
library;

// Pokreće se sa `dart test -p chrome test/browser_key_value_storage_test.dart`.
// Uvozi samo čist Dart (bez Flutter-a), pa se isti fajl kompajlira za pregledač.
// Pravi localStorage pregledača, ne imitacija.
import 'package:session_storage/src/browser_key_value_storage_web.dart';
import 'package:session_storage/src/key_value_session_store.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUp(() => web.window.localStorage.clear());

  test('upis, čitanje i brisanje idu u localStorage', () async {
    final storage = BrowserKeyValueStorage();

    expect(await storage.read('k'), isNull);

    await storage.write('k', 'vrednost');
    expect(web.window.localStorage.getItem('k'), 'vrednost');
    expect(await storage.read('k'), 'vrednost');

    await storage.delete('k');
    expect(web.window.localStorage.getItem('k'), isNull);
  });

  test('prijava ostaje posle osvežavanja stranice', () async {
    await KeyValueSessionStore(BrowserKeyValueStorage()).write('jwt');

    // Osvežena stranica: novi objekti, isti localStorage.
    final refreshed = KeyValueSessionStore(BrowserKeyValueStorage());

    expect(await refreshed.read(), 'jwt');
    expect(
      web.window.localStorage.getItem(KeyValueSessionStore.defaultKey),
      'jwt',
    );
  });

  test('odjava briše token iz localStorage', () async {
    final store = KeyValueSessionStore(BrowserKeyValueStorage());
    await store.write('jwt');

    await store.clear();

    expect(
      web.window.localStorage.getItem(KeyValueSessionStore.defaultKey),
      isNull,
    );
    expect(await KeyValueSessionStore(BrowserKeyValueStorage()).read(), isNull);
  });

  test('tuđi zapisi u localStorage ostaju', () async {
    web.window.localStorage.setItem('nesto_drugo', 'ostaje');
    final store = KeyValueSessionStore(BrowserKeyValueStorage());

    await store.write('jwt');
    await store.clear();

    expect(web.window.localStorage.getItem('nesto_drugo'), 'ostaje');
  });
}
