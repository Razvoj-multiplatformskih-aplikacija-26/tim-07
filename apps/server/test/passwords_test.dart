import 'package:server/server.dart';
import 'package:test/test.dart';

void main() {
  test('heš je Argon2id u PHC formatu i ne sadrži lozinku', () async {
    final hash = await hashPassword('tajna-lozinka');

    expect(hash, startsWith(r'$argon2id$'));
    expect(hash, isNot(contains('tajna-lozinka')));
  });

  test('ista lozinka daje različit heš (so), a oba se proveravaju', () async {
    final first = await hashPassword('lozinka123');
    final second = await hashPassword('lozinka123');

    expect(first, isNot(second));
    expect(await verifyPassword('lozinka123', first), isTrue);
    expect(await verifyPassword('lozinka123', second), isTrue);
  });

  test('pogrešna lozinka i neispravan heš daju false', () async {
    final hash = await hashPassword('lozinka123');

    expect(await verifyPassword('Lozinka123', hash), isFalse);
    expect(await verifyPassword('lozinka123', 'nije-hes'), isFalse);
  });
}
