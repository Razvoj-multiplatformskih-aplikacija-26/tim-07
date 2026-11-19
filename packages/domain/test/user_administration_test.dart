import 'package:domain/domain.dart';
import 'package:test/test.dart';

AppUser person(
  int id,
  String first,
  String last,
  UserRole role, {
  String? email,
}) => AppUser(
  id: UserId(id),
  firstName: first,
  lastName: last,
  email: email ?? '${first.toLowerCase()}@example.com',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026, 1, 1),
);

final admin = person(1, 'Admin', 'Adminović', UserRole.admin);
final otherAdmin = person(2, 'Drugi', 'Admin', UserRole.admin);
final owner = person(3, 'Petar', 'Vlasnik', UserRole.owner);
final jovan = person(4, 'Jovan', 'Petrović', UserRole.user);
final ana = person(5, 'Ana', 'Anić', UserRole.user);
final djordje = person(6, 'Đorđe', 'Šarić', UserRole.user);

final all = [owner, jovan, djordje, admin, ana, otherAdmin];

List<int> ids(Iterable<AppUser> users) => [for (final u in users) u.id.value];

void main() {
  group('nalog', () {
    test('novi nalog je aktivan', () {
      expect(jovan.isActive, isTrue);
    });

    test('copyWith menja samo stanje i čuva ostalo', () {
      final off = jovan.copyWith(isActive: false);

      expect(off.isActive, isFalse);
      expect(off.id, jovan.id);
      expect(off.email, jovan.email);
      expect(off.copyWith(firstName: 'Marko').isActive, isFalse);
      expect(off.copyWith(isActive: true).isActive, isTrue);
    });
  });

  group('prava', () {
    test('samo administrator upravlja nalozima', () {
      expect(canManageUsers(admin), isTrue);
      expect(canManageUsers(owner), isFalse);
      expect(canManageUsers(jovan), isFalse);
    });

    test(
      'administrator deaktivira tuđ nalog, uključujući drugog administratora',
      () {
        expect(canDeactivateUser(admin, jovan), isTrue);
        expect(canDeactivateUser(admin, owner), isTrue);
        expect(canDeactivateUser(admin, otherAdmin), isTrue);
      },
    );

    test('svoj nalog administrator ne deaktivira', () {
      expect(canDeactivateUser(admin, admin), isFalse);
    });

    test('vlasnik i korisnik ne deaktiviraju nikoga', () {
      expect(canDeactivateUser(owner, jovan), isFalse);
      expect(canDeactivateUser(jovan, ana), isFalse);
      expect(canDeactivateUser(owner, owner), isFalse);
    });
  });

  group('filterUsers', () {
    test('bez filtera: svi, po prezimenu, imenu i id', () {
      // Adminović, Admin (Drugi), Anić, Petrović, Šarić, Vlasnik; prezime „Admin“
      // dolazi pre „Adminović“.
      expect(ids(filterUsers(all)), [2, 1, 5, 4, 6, 3]);
    });

    test('po ulozi', () {
      expect(ids(filterUsers(all, role: UserRole.admin)), [2, 1]);
      expect(ids(filterUsers(all, role: UserRole.owner)), [3]);
      expect(ids(filterUsers(all, role: UserRole.user)), [5, 4, 6]);
    });

    test('pretraga po imenu, prezimenu i email-u', () {
      expect(ids(filterUsers(all, search: 'jovan')), [4]);
      expect(ids(filterUsers(all, search: 'vlasnik')), [3]);
      expect(ids(filterUsers(all, search: 'ana@example')), [5]);
    });

    test('pretraga ne razlikuje slova i dijakritike', () {
      expect(ids(filterUsers(all, search: 'PETROVIC')), [4]);
      expect(ids(filterUsers(all, search: 'djordje sarić')), [6]);
      expect(ids(filterUsers(all, search: 'ĐORĐE')), [6]);
    });

    test('svaka reč mora da se nađe', () {
      expect(ids(filterUsers(all, search: 'jovan petrović')), [4]);
      expect(filterUsers(all, search: 'jovan šarić'), isEmpty);
    });

    test('razmaci i prazna pretraga ne sužavaju', () {
      expect(filterUsers(all, search: '   '), hasLength(6));
    });

    test('uloga i pretraga rade zajedno', () {
      expect(ids(filterUsers(all, role: UserRole.user, search: 'an')), [5, 4]);
      expect(filterUsers(all, role: UserRole.owner, search: 'jovan'), isEmpty);
    });

    test('ne menja ulaz', () {
      final before = ids(all);

      filterUsers(all);

      expect(ids(all), before);
    });
  });
}
