@TestOn('vm')
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:session_storage/session_storage.dart';

// Proverava samo naš adapter (ključ i prosleđivanje). Sam Keychain, Keystore,
// Credential Manager i libsecret se proveravaju na uređaju, ne ovde.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('upis, čitanje i brisanje idu u bezbedno skladište', () async {
    const storage = SecureKeyValueStorage();

    expect(await storage.read('k'), isNull);

    await storage.write('k', 'vrednost');
    expect(await storage.read('k'), 'vrednost');

    await storage.delete('k');
    expect(await storage.read('k'), isNull);
  });

  test('prijava preživljava ponovno pokretanje', () async {
    await KeyValueSessionStore(const SecureKeyValueStorage()).write('jwt');

    final restarted = KeyValueSessionStore(const SecureKeyValueStorage());

    expect(await restarted.read(), 'jwt');
  });

  test('odjava briše sačuvan token', () async {
    final store = KeyValueSessionStore(const SecureKeyValueStorage());
    await store.write('jwt');

    await store.clear();

    expect(await store.read(), isNull);
    expect(
      await const SecureKeyValueStorage().read(KeyValueSessionStore.defaultKey),
      isNull,
    );
  });

  test('na VM-u se pravi bezbedno skladište, ne skladište pregledača', () {
    expect(createSessionStore(), isA<KeyValueSessionStore>());
    expect(BrowserKeyValueStorage.new, throwsUnsupportedError);
  });
}
