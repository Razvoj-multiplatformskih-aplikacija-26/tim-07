import 'dart:io';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

AppUser person(int id, UserRole role) => AppUser(
  id: UserId(id),
  firstName: 'Ime$id',
  lastName: 'Prezime$id',
  email: 'korisnik$id@example.com',
  phoneNumber: '064000000$id',
  dateOfBirth: DateTime(1999, 1, 1),
  role: role,
  createdAt: DateTime(2026, 1, 1),
);

// Korisnici mobilne aplikacije (rezervaciju je napravio prvi).
final ana = person(1, UserRole.user);
final marko = person(2, UserRole.user);

// Vlasnici: prvi je vlasnik terena u testu, drugi ima svoj teren negde drugde.
final owner = person(10, UserRole.owner);
final otherOwner = person(11, UserRole.owner);

final admin = person(99, UserRole.admin);

final everyone = {
  'korisnik (podnosilac)': ana,
  'drugi korisnik': marko,
  'vlasnik terena': owner,
  'tuđi vlasnik': otherOwner,
  'administrator': admin,
};

SportsField field({
  bool isActive = true,
  ApprovalStatus approval = ApprovalStatus.approved,
}) => SportsField(
  id: const FieldId(3),
  ownerId: owner.id,
  name: 'Padel Arena',
  description: 'Dva terena',
  sport: SportType.padel,
  address: 'Dorćol 1',
  city: 'Beograd',
  pricePerHour: 3000,
  contactPhone: '0641234567',
  confirmationMode: ConfirmationMode.manual,
  isActive: isActive,
  approvalStatus: approval,
);

Reservation reservation(ReservationStatus status, {DateTime? checkedInAt}) =>
    Reservation(
      id: const ReservationId(7),
      fieldId: const FieldId(3),
      userId: ana.id,
      startTime: DateTime.utc(2026, 11, 20, 17),
      endTime: DateTime.utc(2026, 11, 20, 18),
      totalPrice: 3000,
      status: status,
      checkedInAt: checkedInAt,
      createdAt: DateTime.utc(2026, 11, 1),
    );

void main() {
  final tereni = field();

  group('prijava po aplikaciji', () {
    test('mobilna aplikacija je za korisnike, backoffice za osoblje', () {
      expect(canSignIn(UserRole.user, ClientApp.mobile), isTrue);
      expect(canSignIn(UserRole.owner, ClientApp.mobile), isFalse);
      expect(canSignIn(UserRole.admin, ClientApp.mobile), isFalse);

      expect(canSignIn(UserRole.user, ClientApp.backoffice), isFalse);
      expect(canSignIn(UserRole.owner, ClientApp.backoffice), isTrue);
      expect(canSignIn(UserRole.admin, ClientApp.backoffice), isTrue);
    });

    test('svaka uloga sme u bar jednu aplikaciju', () {
      for (final role in UserRole.values) {
        expect(
          ClientApp.values.any((app) => canSignIn(role, app)),
          isTrue,
          reason: role.name,
        );
      }
    });
  });

  group('kreiranje rezervacije', () {
    test('samo korisnik', () {
      expect(canCreateReservation(ana), isTrue);
      expect(canCreateReservation(marko), isTrue);
      expect(canCreateReservation(owner), isFalse);
      expect(canCreateReservation(admin), isFalse);
    });
  });

  group('ko vidi rezervaciju', () {
    for (final status in ReservationStatus.values) {
      test('u stanju ${status.name}', () {
        final r = reservation(status);

        expect(
          canViewReservation(ana, r, tereni),
          isTrue,
          reason: 'podnosilac',
        );
        expect(
          canViewReservation(marko, r, tereni),
          isFalse,
          reason: 'tuđ zapis',
        );
        expect(
          canViewReservation(owner, r, tereni),
          isTrue,
          reason: 'vlasnik terena',
        );
        expect(
          canViewReservation(otherOwner, r, tereni),
          isFalse,
          reason: 'tuđi vlasnik',
        );
        expect(
          canViewReservation(admin, r, tereni),
          isTrue,
          reason: 'administrator',
        );
      });
    }
  });

  group('potvrda i odbijanje', () {
    for (final status in ReservationStatus.values) {
      test(
        'u stanju ${status.name} sme samo vlasnik terena, i samo na čekanju',
        () {
          final r = reservation(status);
          final onlyOwnerWhenPending = status == ReservationStatus.pending;

          for (final entry in everyone.entries) {
            final expected = onlyOwnerWhenPending && entry.value.id == owner.id;

            expect(
              canConfirmReservation(entry.value, r, tereni),
              expected,
              reason: 'potvrda: ${entry.key}',
            );
            expect(
              canRejectReservation(entry.value, r, tereni),
              expected,
              reason: 'odbijanje: ${entry.key}',
            );
          }
        },
      );
    }

    test('korisnik nikad ne potvrđuje ni odbija, ni svoju rezervaciju', () {
      final r = reservation(ReservationStatus.pending);

      expect(canConfirmReservation(ana, r, tereni), isFalse);
      expect(canRejectReservation(ana, r, tereni), isFalse);
    });

    test('administrator ne potvrđuje, samo otkazuje', () {
      final r = reservation(ReservationStatus.pending);

      expect(canConfirmReservation(admin, r, tereni), isFalse);
      expect(canRejectReservation(admin, r, tereni), isFalse);
      expect(canCancelReservation(admin, r, tereni), isTrue);
    });
  });

  group('otkazivanje', () {
    const active = [ReservationStatus.pending, ReservationStatus.confirmed];

    for (final status in active) {
      test('aktivna rezervacija (${status.name}): ko sme', () {
        final r = reservation(status);

        expect(canCancelReservation(ana, r, tereni), isTrue, reason: 'svoju');
        expect(canCancelReservation(marko, r, tereni), isFalse, reason: 'tuđu');
        expect(
          canCancelReservation(owner, r, tereni),
          isTrue,
          reason: 'na svom terenu',
        );
        expect(
          canCancelReservation(otherOwner, r, tereni),
          isFalse,
          reason: 'na tuđem terenu',
        );
        expect(
          canCancelReservation(admin, r, tereni),
          isTrue,
          reason: 'administrator',
        );
      });
    }

    for (final status in [
      ReservationStatus.completed,
      ReservationStatus.cancelled,
    ]) {
      test('konačno stanje (${status.name}) ne može niko', () {
        final r = reservation(status);

        for (final entry in everyone.entries) {
          expect(
            canCancelReservation(entry.value, r, tereni),
            isFalse,
            reason: entry.key,
          );
        }
      });
    }
  });

  group('dolazak (check-in)', () {
    test('samo korisnik koji je rezervisao, na potvrđenoj rezervaciji', () {
      final r = reservation(ReservationStatus.confirmed);

      expect(canCheckInReservation(ana, r), isTrue);
      expect(canCheckInReservation(marko, r), isFalse, reason: 'tuđ zapis');
      expect(canCheckInReservation(owner, r), isFalse);
      expect(canCheckInReservation(admin, r), isFalse);
    });

    test('ne u ostalim stanjima', () {
      for (final status in ReservationStatus.values) {
        if (status == ReservationStatus.confirmed) continue;

        expect(
          canCheckInReservation(ana, reservation(status)),
          isFalse,
          reason: status.name,
        );
      }
    });

    test('ne dvaput', () {
      final done = reservation(
        ReservationStatus.confirmed,
        checkedInAt: DateTime.utc(2026, 11, 19, 10),
      );

      expect(canCheckInReservation(ana, done), isFalse);
    });
  });

  group('dugmad za rezervaciju (allowedReservationActions)', () {
    test('na čekanju: vlasnik potvrđuje, odbija i otkazuje', () {
      final r = reservation(ReservationStatus.pending);

      expect(allowedReservationActions(owner, r, tereni), {
        ReservationAction.confirm,
        ReservationAction.reject,
        ReservationAction.cancel,
      });
    });

    test(
      'potvrđena: vlasnik samo otkazuje, korisnik otkazuje i potvrđuje dolazak',
      () {
        final r = reservation(ReservationStatus.confirmed);

        expect(allowedReservationActions(owner, r, tereni), {
          ReservationAction.cancel,
        });
        expect(allowedReservationActions(ana, r, tereni), {
          ReservationAction.cancel,
          ReservationAction.checkIn,
        });
      },
    );

    test('korisnik na rezervaciji na čekanju samo otkazuje', () {
      final r = reservation(ReservationStatus.pending);

      expect(allowedReservationActions(ana, r, tereni), {
        ReservationAction.cancel,
      });
    });

    test('tuđ zapis: nijedna akcija', () {
      for (final status in ReservationStatus.values) {
        final r = reservation(status);

        expect(allowedReservationActions(marko, r, tereni), isEmpty);
        expect(allowedReservationActions(otherOwner, r, tereni), isEmpty);
      }
    });

    test('konačna stanja: nijedna akcija nikome', () {
      for (final status in [
        ReservationStatus.completed,
        ReservationStatus.cancelled,
      ]) {
        final r = reservation(status);

        for (final entry in everyone.entries) {
          expect(
            allowedReservationActions(entry.value, r, tereni),
            isEmpty,
            reason: '${status.name}: ${entry.key}',
          );
        }
      }
    });

    test('skup se slaže sa pojedinačnim pravima', () {
      for (final status in ReservationStatus.values) {
        final r = reservation(status);

        for (final entry in everyone.entries) {
          final user = entry.value;
          final actions = allowedReservationActions(user, r, tereni);

          expect(
            actions.contains(ReservationAction.confirm),
            canConfirmReservation(user, r, tereni),
          );
          expect(
            actions.contains(ReservationAction.reject),
            canRejectReservation(user, r, tereni),
          );
          expect(
            actions.contains(ReservationAction.cancel),
            canCancelReservation(user, r, tereni),
          );
          expect(
            actions.contains(ReservationAction.checkIn),
            canCheckInReservation(user, r),
          );
        }
      }
    });
  });

  group('tereni', () {
    test('javni teren vidi svako, i bez prijave', () {
      final javni = field();

      expect(canViewField(null, javni), isTrue);
      for (final user in everyone.values) {
        expect(canViewField(user, javni), isTrue);
      }
    });

    for (final entry in {
      'čeka odobrenje': field(approval: ApprovalStatus.pending),
      'odbijen': field(approval: ApprovalStatus.rejected),
      'neaktivan': field(isActive: false),
    }.entries) {
      test(
        'teren koji nije javan (${entry.key}) vide samo vlasnik i administrator',
        () {
          final f = entry.value;

          expect(canViewField(null, f), isFalse, reason: 'bez prijave');
          expect(canViewField(ana, f), isFalse, reason: 'korisnik');
          expect(canViewField(otherOwner, f), isFalse, reason: 'tuđi vlasnik');
          expect(canViewField(owner, f), isTrue, reason: 'vlasnik');
          expect(canViewField(admin, f), isTrue, reason: 'administrator');
        },
      );
    }

    test('teren objavljuje vlasnik', () {
      expect(canCreateField(owner), isTrue);
      expect(canCreateField(ana), isFalse);
      expect(canCreateField(admin), isFalse);
    });

    test(
      'menja ga samo vlasnik tog terena, ne ni administrator ni tuđi vlasnik',
      () {
        expect(canManageField(owner, tereni), isTrue);
        expect(canManageField(otherOwner, tereni), isFalse);
        expect(canManageField(admin, tereni), isFalse);
        expect(canManageField(ana, tereni), isFalse);
      },
    );

    test('korisnik čiji je id isti kao id vlasnika ipak nije vlasnik', () {
      final impostor = person(owner.id.value, UserRole.user);

      expect(canManageField(impostor, tereni), isFalse);
      expect(
        canViewField(impostor, field(approval: ApprovalStatus.pending)),
        isFalse,
      );
    });

    test('objavljivanje odobrava samo administrator', () {
      expect(canReviewField(admin), isTrue);
      expect(canReviewField(owner), isFalse);
      expect(canReviewField(ana), isFalse);
    });
  });

  group('statistika i nalozi', () {
    test('statistiku vide vlasnik i administrator', () {
      expect(canViewStatistics(owner), isTrue);
      expect(canViewStatistics(admin), isTrue);
      expect(canViewStatistics(ana), isFalse);
    });

    test('naloge vodi samo administrator', () {
      expect(canManageUsers(admin), isTrue);
      expect(canManageUsers(owner), isFalse);
      expect(canManageUsers(ana), isFalse);
    });
  });

  test('svaka uloga ima bar jedno pravo, pa nijedna nije zaboravljena', () {
    for (final role in UserRole.values) {
      final user = person(50, role);
      final any =
          canCreateReservation(user) ||
          canCreateField(user) ||
          canReviewField(user) ||
          canViewStatistics(user) ||
          canManageUsers(user);

      expect(any, isTrue, reason: role.name);
    }
  });

  test('aplikacije i server ne proveravaju ulogu sami, prava su samo u domenu', () {
    // `UserRole.x` sme da stoji u podacima i prevodu (role: UserRole.user,
    // byName), ali ne u poređenju: odluku donosi funkcija iz permissions.dart.
    final comparison = RegExp(
      r'(\.role\s*[!=]=\s*UserRole\.)|(UserRole\.\w+\s*[!=]=\s*\w+\.role)|(switch\s*\(\s*\w+\.role\s*\))',
    );
    final roots = [
      Directory('../../apps/server/lib'),
      Directory('../../apps/mobile/lib'),
      Directory('../../apps/backoffice/lib'),
    ];

    var scanned = 0;
    for (final root in roots.where((d) => d.existsSync())) {
      for (final file
          in root
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        scanned++;
        expect(
          comparison.hasMatch(file.readAsStringSync()),
          isFalse,
          reason:
              '${file.path} sam proverava ulogu; koristi funkciju iz permissions.dart',
        );
      }
    }
    expect(scanned, greaterThan(0));
  });
}
