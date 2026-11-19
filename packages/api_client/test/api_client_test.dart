import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

http.Response jsonResponse(int status, Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> errorBody(String code, [Map<String, Object?>? details]) =>
    ErrorDto(code: code, details: details ?? const {}).toJson();

Map<String, Object?> reservationJson({
  int id = 7,
  int userId = 2,
  String status = 'pending',
}) => {
  'id': id,
  'fieldId': 3,
  'userId': userId,
  'startTime': '2026-11-20T17:00:00.000Z',
  'endTime': '2026-11-20T18:30:00.000Z',
  'totalPrice': 4500,
  'status': status,
  'paymentStatus': 'unpaid',
  'createdAt': '2026-11-17T09:15:00.000Z',
};

Map<String, Object?> fieldJson({
  int id = 3,
  int ownerId = 9,
  String sport = 'padel',
  String approval = 'approved',
}) => {
  'id': id,
  'ownerId': ownerId,
  'name': 'Padel Arena',
  'description': 'Dva zatvorena terena',
  'sport': sport,
  'address': 'Dorćol 1',
  'city': 'Beograd',
  'pricePerHour': 3000,
  'contactPhone': '0641234567',
  'imageUrls': <String>[],
  'confirmationMode': 'manual',
  'isActive': true,
  'approvalStatus': approval,
};

Map<String, Object?> page(List<Object?> items, {int? total, int offset = 0}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'limit': ApiPaging.maxLimit,
      'offset': offset,
    };

final base = Uri.parse('http://localhost:8080');

ApiClient clientFor(
  MockClient server, {
  SessionStore? session,
  Duration timeout = const Duration(seconds: 5),
  Uri? baseUri,
}) => ApiClient(
  baseUri: baseUri ?? base,
  session: session,
  httpClient: server,
  timeout: timeout,
);

Future<MemorySessionStore> signedIn([String token = 'token-of-ana']) async {
  final store = MemorySessionStore();
  await store.write(token);
  return store;
}

void main() {
  group('ApiClient: zahtev', () {
    test('šalje token u Authorization zaglavlju i traži JSON', () async {
      late http.BaseRequest seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, page([]));
        }),
        session: await signedIn(),
      );

      await HttpReservationRepository(api).getReservations();

      expect(seen.headers['authorization'], 'Bearer token-of-ana');
      expect(seen.headers['accept'], 'application/json');
    });

    test('bez prijave ne šalje Authorization (javni katalog)', () async {
      late http.BaseRequest seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, page([fieldJson()]));
        }),
      );

      final fields = await HttpFieldRepository(api).getPublicFields();

      expect(seen.headers.containsKey('authorization'), isFalse);
      expect(fields, hasLength(1));
    });

    test('adresa servera sa putanjom se čuva', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, page([]));
        }),
        baseUri: Uri.parse('http://localhost:8080/api/'),
      );

      await HttpReservationRepository(api).getReservations();

      expect(seen.path, '/api/reservations');
    });

    test('telo se šalje kao JSON', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(201, reservationJson());
        }),
        session: await signedIn(),
      );

      await HttpReservationRepository(api).createReservation(
        fieldId: const FieldId(3),
        userId: const UserId(2),
        startTime: DateTime.utc(2026, 11, 20, 17),
        endTime: DateTime.utc(2026, 11, 20, 18, 30),
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/reservations');
      expect(seen.headers['content-type'], contains('application/json'));
      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body, {
        'fieldId': 3,
        'startTime': '2026-11-20T17:00:00.000Z',
        'endTime': '2026-11-20T18:30:00.000Z',
      });
      // Identitet je u tokenu, ne u telu zahteva.
      expect(body.containsKey('userId'), isFalse);
    });
  });

  group('ApiClient: greške', () {
    test('server koji odbije pravilo stiže kao kod i podaci', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(409, errorBody('slot_taken')),
        ),
        session: await signedIn(),
      );

      await expectLater(
        HttpReservationRepository(api).createReservation(
          fieldId: const FieldId(3),
          userId: const UserId(2),
          startTime: DateTime.utc(2026, 11, 20, 17),
          endTime: DateTime.utc(2026, 11, 20, 18),
        ),
        throwsA(
          isA<ServerRejectedException>().having(
            (e) => e.error.code,
            'code',
            ErrorCodes.slotTaken,
          ),
        ),
      );
    });

    test(
      'korisnik vidi istu poruku kao kada pravilo proveri klijent',
      () async {
        final api = clientFor(
          MockClient(
            (request) async => jsonResponse(
              422,
              errorBody('cancellation_deadline_expired', {'hours': 5}),
            ),
          ),
          session: await signedIn(),
        );

        Object? caught;
        try {
          await HttpReservationRepository(api)
              .cancelReservation(const ReservationId(7));
        } catch (error) {
          caught = error;
        }

        expect(
          describeError(caught!),
          validationMessage(const CancellationDeadlineExpired()),
        );
      },
    );

    test('nema mreže: ServerUnreachableException', () async {
      final api = clientFor(
        MockClient(
          (request) async =>
              throw http.ClientException('Connection refused', request.url),
        ),
      );

      await expectLater(
        HttpFieldRepository(api).getFields(),
        throwsA(isA<ServerUnreachableException>()),
      );
    });

    test('server ne odgovara na vreme: ne čeka beskonačno', () async {
      final api = clientFor(
        MockClient((request) async {
          await Future<void>.delayed(const Duration(seconds: 2));
          return jsonResponse(200, page([]));
        }),
        timeout: const Duration(milliseconds: 50),
      );

      final started = DateTime.now();
      await expectLater(
        HttpFieldRepository(api).getFields(),
        throwsA(isA<ServerUnreachableException>()),
      );

      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 1)),
      );
    });

    test('HTML sa proxy-ja nije tehnički tekst za korisnika', () async {
      final api = clientFor(
        MockClient(
          (request) async => http.Response(
            '<html><body>502 Bad Gateway nginx</body></html>',
            502,
            headers: {'content-type': 'text/html'},
          ),
        ),
      );

      Object? caught;
      try {
        await HttpFieldRepository(api).getFields();
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<ServerRejectedException>());
      expect(describeError(caught!), genericErrorMessage);
      expect(describeError(caught), isNot(contains('nginx')));
    });

    test('uspešan odgovor koji nije JSON je greška servera, ne pad', () async {
      final api = clientFor(
        MockClient((request) async => http.Response('nije json', 200)),
      );

      await expectLater(
        HttpFieldRepository(api).getFields(),
        throwsA(
          isA<ServerRejectedException>().having(
            (e) => e.error.code,
            'code',
            ErrorCodes.internal,
          ),
        ),
      );
    });

    test('nepoznat kod greške (stara aplikacija) daje opštu poruku', () async {
      final api = clientFor(
        MockClient(
          (request) async =>
              jsonResponse(422, errorBody('court_closed_for_holiday')),
        ),
        session: await signedIn(),
      );

      Object? caught;
      try {
        await HttpReservationRepository(api)
            .cancelReservation(const ReservationId(7));
      } catch (error) {
        caught = error;
      }

      expect(describeError(caught!), genericErrorMessage);
    });

    test('token_expired briše prijavu i javlja istek', () async {
      final store = await signedIn();
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(401, errorBody('token_expired')),
        ),
        session: store,
      );
      final expired = expectLater(api.expirations, emits(anything));

      await expectLater(
        HttpReservationRepository(api).getReservations(),
        throwsA(
          isA<ServerRejectedException>().having(
            (e) => isSessionExpired(e),
            'isSessionExpired',
            isTrue,
          ),
        ),
      );

      await expired;
      expect(await store.read(), isNull);
    });

    test('pogrešna lozinka nije istek prijave', () async {
      final store = MemorySessionStore();
      final api = clientFor(
        MockClient(
          (request) async =>
              jsonResponse(401, errorBody('invalid_credentials')),
        ),
        session: store,
      );
      var expirations = 0;
      api.expirations.listen((_) => expirations++);

      await expectLater(
        HttpSessionRepository(api).logIn(email: 'a@b.rs', password: 'x'),
        throwsA(
          isA<ServerRejectedException>().having(
            (e) => describeError(e),
            'message',
            'Pogrešan e-mail ili lozinka.',
          ),
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(expirations, 0);
      expect(await store.read(), isNull);
    });
  });

  group('HttpReservationRepository', () {
    test('uzima sve strane liste redom', () async {
      final offsets = <String?>[];
      final api = clientFor(
        MockClient((request) async {
          final offset = int.parse(request.url.queryParameters['offset']!);
          offsets.add(request.url.queryParameters['offset']);
          expect(request.url.queryParameters['limit'], '${ApiPaging.maxLimit}');
          final items = [
            for (var i = offset; i < offset + 2 && i < 5; i++)
              reservationJson(id: i + 1),
          ];
          return jsonResponse(200, page(items, total: 5, offset: offset));
        }),
        session: await signedIn(),
      );

      final all = await HttpReservationRepository(api).getReservations();

      expect(all.map((r) => r.id.value), [1, 2, 3, 4, 5]);
      expect(offsets, ['0', '2', '4']);
    });

    test('pretraga šalje filtere, sortiranje i stranu serveru', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, {
            'items': [reservationJson()],
            'total': 87,
            'limit': 20,
            'offset': 40,
          });
        }),
        session: await signedIn(),
      );

      final result = await HttpReservationRepository(api).searchReservations(
        ReservationQuery(
          fieldId: const FieldId(3),
          status: ReservationStatus.pending,
          fromDate: DateTime(2026, 12, 1, 17),
          toDate: DateTime(2026, 12, 31),
          search: '  Petrović ',
          sortKey: ReservationSortKey.user,
          ascending: false,
          offset: 40,
        ),
      );

      expect(result.total, 87);
      expect(result.offset, 40);
      expect(result.hasMore, isTrue);
      expect(seen.queryParameters, {
        'fieldId': '3',
        'status': 'pending',
        'from': '2026-12-01',
        'to': '2026-12-31',
        'search': 'Petrović',
        'sort': 'user',
        'order': 'desc',
        'limit': '20',
        'offset': '40',
      });
    });

    test('pretraga bez filtera šalje samo sortiranje i stranu', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, page([reservationJson()]));
        }),
        session: await signedIn(),
      );

      await HttpReservationRepository(
        api,
      ).searchReservations(const ReservationQuery());

      expect(seen.queryParameters, {
        'sort': 'start',
        'order': 'asc',
        'limit': '20',
        'offset': '0',
      });
    });

    test('pretraga preskače rezervaciju sa nepoznatim stanjem', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(
            200,
            page([
              reservationJson(id: 1),
              reservationJson(id: 2, status: 'no_show'),
            ]),
          ),
        ),
        session: await signedIn(),
      );

      final result = await HttpReservationRepository(
        api,
      ).searchReservations(const ReservationQuery());

      expect(result.items.map((r) => r.id.value), [1]);
    });

    test('jedna strana nosi ukupan broj za tabelu', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, {
            'items': [reservationJson()],
            'total': 87,
            'limit': 20,
            'offset': 40,
          });
        }),
        session: await signedIn(),
      );

      final result = await HttpReservationRepository(api).getReservationsPage(
        fieldId: const FieldId(3),
        status: ReservationStatus.confirmed,
        offset: 40,
      );

      expect(result.total, 87);
      expect(result.hasMore, isTrue);
      expect(seen.queryParameters['fieldId'], '3');
      expect(seen.queryParameters['status'], 'confirmed');
      expect(seen.queryParameters['limit'], '20');
      expect(seen.queryParameters['offset'], '40');
    });

    test(
      'rezervacija sa nepoznatim stanjem se preskače, lista ostaje',
      () async {
        final api = clientFor(
          MockClient(
            (request) async => jsonResponse(
              200,
              page([
                reservationJson(id: 1),
                reservationJson(id: 2, status: 'no_show'),
                reservationJson(id: 3),
              ]),
            ),
          ),
          session: await signedIn(),
        );

        final all = await HttpReservationRepository(api).getReservations();

        expect(all.map((r) => r.id.value), [1, 3]);
      },
    );

    test('po terenu šalje fieldId', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, page([]));
        }),
        session: await signedIn(),
      );

      await HttpReservationRepository(api)
          .getReservationsByField(const FieldId(3));

      expect(seen.queryParameters['fieldId'], '3');
    });

    test('po korisniku ostavlja samo njegove', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(
            200,
            page([
              reservationJson(id: 1, userId: 2),
              reservationJson(id: 2, userId: 5),
            ]),
          ),
        ),
        session: await signedIn(),
      );

      final mine = await HttpReservationRepository(api)
          .getReservationsByUser(const UserId(2));

      expect(mine.map((r) => r.id.value), [1]);
    });

    test('tuđa ili nepostojeća rezervacija je null (404)', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(404, errorBody('not_found')),
        ),
        session: await signedIn(),
      );

      expect(
        await HttpReservationRepository(api)
            .getReservationById(const ReservationId(99)),
        isNull,
      );
    });

    test('druga greška nije null nego izuzetak', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(403, errorBody('forbidden')),
        ),
        session: await signedIn(),
      );

      await expectLater(
        HttpReservationRepository(api)
            .getReservationById(const ReservationId(7)),
        throwsA(isA<ServerRejectedException>()),
      );
    });

    test('potvrda, otkazivanje i dolazak idu na svoje adrese', () async {
      final calls = <String>[];
      final api = clientFor(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return jsonResponse(200, reservationJson());
        }),
        session: await signedIn(),
      );
      final repository = HttpReservationRepository(api);

      await repository.updateReservationStatus(
        reservationId: const ReservationId(7),
        status: ReservationStatus.confirmed,
      );
      await repository.updateReservationStatus(
        reservationId: const ReservationId(7),
        status: ReservationStatus.cancelled,
      );
      await repository.cancelReservation(const ReservationId(7));
      await repository.checkIn(const ReservationId(7));
      await repository.rejectReservation(
        const ReservationId(7),
        reason: 'Teren se renovira',
      );

      expect(calls, [
        'POST /reservations/7/confirm',
        'POST /reservations/7/cancel',
        'POST /reservations/7/cancel',
        'POST /reservations/7/check-in',
        'POST /reservations/7/reject',
      ]);
    });

    test('razlog odbijanja ide u telu', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, reservationJson());
        }),
        session: await signedIn(),
      );

      await HttpReservationRepository(
        api,
      ).rejectReservation(const ReservationId(7), reason: 'Teren se renovira');

      expect(jsonDecode(seen.body), {'reason': 'Teren se renovira'});
    });

    test('završetak i vraćanje na čekanje se ne šalju serveru', () async {
      var calls = 0;
      final api = clientFor(
        MockClient((request) async {
          calls++;
          return jsonResponse(200, reservationJson());
        }),
        session: await signedIn(),
      );
      final repository = HttpReservationRepository(api);

      for (final status in [
        ReservationStatus.completed,
        ReservationStatus.pending,
      ]) {
        await expectLater(
          repository.updateReservationStatus(
            reservationId: const ReservationId(7),
            status: status,
          ),
          throwsA(isA<ReservationRuleViolation>()),
        );
      }

      expect(calls, 0);
    });

    test('kreirana rezervacija se vraća kao domenski objekat', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(201, reservationJson(id: 12)),
        ),
        session: await signedIn(),
      );

      final reservation = await HttpReservationRepository(api)
          .createReservation(
            fieldId: const FieldId(3),
            userId: const UserId(2),
            startTime: DateTime.utc(2026, 11, 20, 17),
            endTime: DateTime.utc(2026, 11, 20, 18, 30),
          );

      expect(reservation.id, const ReservationId(12));
      expect(reservation.status, ReservationStatus.pending);
      expect(reservation.totalPrice, 4500);
      expect(reservation.startTime, DateTime.utc(2026, 11, 20, 17));
    });
  });

  group('HttpFieldRepository', () {
    test('sportovi sa servera, nepoznat se preskače', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'sports': ['football', 'curling', 'padel'],
          }),
        ),
      );

      final sports = await HttpFieldRepository(api).getAvailableSports();

      expect(sports, [SportType.football, SportType.padel]);
    });

    test('teren sa nepoznatim sportom se preskače u listi', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(
            200,
            page([fieldJson(id: 1), fieldJson(id: 2, sport: 'curling')]),
          ),
        ),
      );

      final fields = await HttpFieldRepository(api).getFields();

      expect(fields.map((f) => f.id.value), [1]);
    });

    test('javni katalog ne prikazuje neodobren teren ni vlasniku', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(
            200,
            page([fieldJson(id: 1), fieldJson(id: 2, approval: 'pending')]),
          ),
        ),
        session: await signedIn(),
      );

      final fields = await HttpFieldRepository(api).getPublicFields();

      expect(fields.map((f) => f.id.value), [1]);
    });

    test('filteri kataloga idu u upitu', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, page([fieldJson()]));
        }),
      );

      final result = await HttpFieldRepository(
        api,
      ).getFieldsPage(sport: SportType.tennis, city: 'Beograd', search: 'ar');

      expect(seen.queryParameters['sport'], 'tennis');
      expect(seen.queryParameters['city'], 'Beograd');
      expect(seen.queryParameters['search'], 'ar');
      expect(result.items, hasLength(1));
    });

    test('nov teren se šalje bez vlasnika i odobrenosti', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(201, fieldJson(approval: 'pending'));
        }),
        session: await signedIn(),
      );

      final created = await HttpFieldRepository(api).createField(
        ownerId: const UserId(9),
        name: 'Padel Arena',
        description: 'Dva zatvorena terena',
        sport: SportType.padel,
        address: 'Dorćol 1',
        city: 'Beograd',
        pricePerHour: 3000,
        contactPhone: '0641234567',
        confirmationMode: ConfirmationMode.manual,
      );

      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(seen.method, 'POST');
      expect(body.containsKey('ownerId'), isFalse);
      expect(body.containsKey('approvalStatus'), isFalse);
      expect(body['sport'], 'padel');
      expect(created.approvalStatus, ApprovalStatus.pending);
    });

    test('izmena terena ide na PATCH sa njegovim id-jem', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, fieldJson());
        }),
        session: await signedIn(),
      );
      final field = FieldDto.fromJson(fieldJson()).toDomain();

      await HttpFieldRepository(api).updateField(field);

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/fields/3');
    });

    test('odluka administratora ide bez id-ja administratora', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, fieldJson(approval: 'rejected'));
        }),
        session: await signedIn(),
      );

      final reviewed = await HttpFieldRepository(api).reviewField(
        fieldId: const FieldId(3),
        reviewerId: const UserId(1),
        decision: ApprovalStatus.rejected,
        reason: 'Nedostaju slike',
      );

      expect(seen.url.path, '/fields/3/review');
      expect(jsonDecode(seen.body), {
        'decision': 'rejected',
        'reason': 'Nedostaju slike',
      });
      expect(reviewed.approvalStatus, ApprovalStatus.rejected);
    });

    test('teren koji ne postoji je null', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(404, errorBody('not_found')),
        ),
      );

      expect(
        await HttpFieldRepository(api).getFieldById(const FieldId(99)),
        isNull,
      );
    });

    test('tereni koji čekaju odobrenje', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, page([fieldJson(approval: 'pending')]));
        }),
        session: await signedIn(),
      );

      final fields = await HttpFieldRepository(api).getFieldsAwaitingApproval();

      expect(seen.path, '/fields/awaiting-approval');
      expect(fields.single.approvalStatus, ApprovalStatus.pending);
    });
  });

  group('HttpScheduleRepository i statistika', () {
    test('radno vreme se čita i menja u celini', () async {
      final calls = <String>[];
      late Object? body;
      final api = clientFor(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'PUT') {
            body = jsonDecode(request.body);
            return http.Response('', 204);
          }
          return jsonResponse(200, {
            'days': [
              {
                'dayOfWeek': 'monday',
                'opensAt': '08:00',
                'closesAt': '22:30',
                'isOpen': true,
              },
            ],
          });
        }),
        session: await signedIn(),
      );
      final repository = HttpScheduleRepository(api);

      final days = await repository.getSchedules(const FieldId(3));
      await repository.replaceSchedules(const FieldId(3), days);

      expect(days.single.closesAt.minute, 30);
      expect(days.single.fieldId, const FieldId(3));
      expect(calls, ['GET /fields/3/schedule', 'PUT /fields/3/schedule']);
      expect((body as Map)['days'], hasLength(1));
    });

    test('blokirani periodi: opseg ide u UTC, blokada se dodaje', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          if (request.method == 'POST') {
            return jsonResponse(201, {
              'fieldId': 3,
              'startTime': '2026-11-21T08:00:00.000Z',
              'endTime': '2026-11-21T12:00:00.000Z',
              'reason': 'Održavanje',
            });
          }
          seen = request.url;
          return jsonResponse(200, page([]));
        }),
        session: await signedIn(),
      );
      final repository = HttpScheduleRepository(api);

      await repository.getBlockedPeriods(
        const FieldId(3),
        from: DateTime.utc(2026, 11, 21),
        to: DateTime.utc(2026, 11, 22),
      );
      final added = await repository.addBlockedPeriod(
        BlockedPeriod(
          fieldId: const FieldId(3),
          startTime: DateTime.utc(2026, 11, 21, 8),
          endTime: DateTime.utc(2026, 11, 21, 12),
          reason: 'Održavanje',
        ),
      );

      expect(seen.queryParameters['from'], '2026-11-21T00:00:00.000Z');
      expect(seen.queryParameters['to'], '2026-11-22T00:00:00.000Z');
      expect(added.reason, 'Održavanje');
    });

    test('statistika šalje vrstu perioda i dan, računa server', () async {
      late Uri seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request.url;
          return jsonResponse(200, {
            'period': 'week',
            'from': '2026-11-15T23:00:00.000Z',
            'to': '2026-11-22T23:00:00.000Z',
            'fields': [
              {
                'fieldId': 3,
                'fieldName': 'Padel Arena',
                'availableMinutes': 5040,
                'bookedMinutes': 1260,
                'completedCount': 6,
                'cancelledCount': 1,
                'activeCount': 2,
              },
            ],
          });
        }),
        session: await signedIn(),
      );

      final report = await HttpStatisticsRepository(api)
          .getOccupancy(period: StatsPeriod.weekOf(DateTime(2026, 11, 18)));

      expect(seen.queryParameters['period'], 'week');
      expect(seen.queryParameters['day'], '2026-11-16');
      expect(report.fields.single.occupancyPercent, 25);
      expect(report.period.from, DateTime.utc(2026, 11, 15, 23));
    });
  });

  group('HttpSessionRepository', () {
    Map<String, Object?> user() => {
      'id': 2,
      'firstName': 'Ana',
      'lastName': 'Jovanović',
      'email': 'ana@example.com',
      'role': 'user',
    };

    test('prijava čuva token i vraća korisnika', () async {
      final store = MemorySessionStore();
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, {
            'token': 'abc.def.ghi',
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': user(),
          });
        }),
        session: store,
      );

      final session = await HttpSessionRepository(api)
          .logIn(email: 'ana@example.com', password: 'tajna');

      expect(seen.url.path, '/auth/login');
      expect(jsonDecode(seen.body), {
        'email': 'ana@example.com',
        'password': 'tajna',
      });
      expect(session.user.role, UserRole.user);
      expect(session.user.fullName, 'Ana Jovanović');
      expect(session.expiresAt, DateTime.utc(2026, 11, 18, 20));
      expect(await store.read(), 'abc.def.ghi');
    });

    test('lozinka se ne čuva nigde u skladištu', () async {
      final store = MemorySessionStore();
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'token': 'abc.def.ghi',
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': user(),
          }),
        ),
        session: store,
      );

      await HttpSessionRepository(api)
          .logIn(email: 'ana@example.com', password: 'tajna');

      expect(await store.read(), isNot(contains('tajna')));
    });

    test('odgovor na prijavu bez tokena je greška servera', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': user(),
          }),
        ),
      );

      await expectLater(
        HttpSessionRepository(api).logIn(email: 'a@b.rs', password: 'x'),
        throwsA(isA<ServerRejectedException>()),
      );
    });

    test('bez sačuvane prijave restore ne zove server', () async {
      var calls = 0;
      final api = clientFor(
        MockClient((request) async {
          calls++;
          return jsonResponse(200, {});
        }),
      );

      expect(await HttpSessionRepository(api).restore(), isNull);
      expect(calls, 0);
    });

    test('posle ponovnog pokretanja prijava se vraća iz tokena', () async {
      final api = clientFor(
        MockClient((request) async {
          expect(request.url.path, '/auth/me');
          expect(request.headers['authorization'], 'Bearer sacuvan-token');
          return jsonResponse(200, {
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': user(),
          });
        }),
        session: await signedIn('sacuvan-token'),
      );

      final session = await HttpSessionRepository(api).restore();

      expect(session!.user.email, 'ana@example.com');
    });

    test('istekla prijava: restore vraća null i briše token', () async {
      final store = await signedIn();
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(401, errorBody('token_expired')),
        ),
        session: store,
      );

      expect(await HttpSessionRepository(api).restore(), isNull);
      expect(await store.read(), isNull);
    });

    test(
      'server nije dostupan: prijava ostaje, korisnik se ne odjavljuje',
      () async {
        final store = await signedIn();
        final api = clientFor(
          MockClient(
            (request) async =>
                throw http.ClientException('Connection refused', request.url),
          ),
          session: store,
        );

        await expectLater(
          HttpSessionRepository(api).restore(),
          throwsA(isA<ServerUnreachableException>()),
        );
        expect(await store.read(), 'token-of-ana');
      },
    );

    test('odjava briše token i ne zove server', () async {
      var calls = 0;
      final store = await signedIn();
      final api = clientFor(
        MockClient((request) async {
          calls++;
          return jsonResponse(200, {});
        }),
        session: store,
      );

      await HttpSessionRepository(api).logOut();

      expect(await store.read(), isNull);
      expect(calls, 0);
    });

    test('nepoznata uloga u odgovoru nije pad aplikacije', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'token': 't',
            'expiresAt': '2026-11-18T20:00:00.000Z',
            'user': {...user(), 'role': 'superuser'},
          }),
        ),
      );

      await expectLater(
        HttpSessionRepository(api).logIn(email: 'a@b.rs', password: 'x'),
        throwsA(isA<ServerRejectedException>()),
      );
    });
  });

  test('timeout se meri i kada server odgovara polako u delovima', () async {
    final api = clientFor(
      MockClient.streaming((request, bodyStream) async {
        final controller = StreamController<List<int>>();
        Timer(const Duration(seconds: 2), controller.close);
        return http.StreamedResponse(controller.stream, 200);
      }),
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      HttpFieldRepository(api).getFields(),
      throwsA(isA<ServerUnreachableException>()),
    );
  });

  group('HttpAvailabilityRepository', () {
    Map<String, Object?> slot(int hour, String state) => {
      'startTime': DateTime.utc(2026, 11, 20, hour).toIso8601String(),
      'endTime': DateTime.utc(2026, 11, 20, hour + 1).toIso8601String(),
      'state': state,
    };

    test('traži dan terena bez prijave i vraća termine sa stanjem', () async {
      late http.BaseRequest seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(200, {
            'fieldId': 3,
            'date': '2026-11-20',
            'slots': [slot(8, 'free'), slot(9, 'taken'), slot(10, 'blocked')],
          });
        }),
      );

      final slots = await HttpAvailabilityRepository(api).getAvailability(
        fieldId: const FieldId(3),
        date: DateTime(2026, 11, 20, 15, 30),
      );

      expect(seen.url.path, '/fields/3/availability');
      expect(seen.url.queryParameters['date'], '2026-11-20');
      expect(seen.headers.containsKey('authorization'), isFalse);
      expect(slots.map((s) => s.state), [
        SlotState.free,
        SlotState.taken,
        SlotState.blocked,
      ]);
      expect(slots.first.duration, const Duration(hours: 1));
    });

    test('termini se vraćaju u lokalnom vremenu', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'fieldId': 3,
            'date': '2026-11-20',
            'slots': [slot(8, 'free')],
          }),
        ),
      );

      final slots = await HttpAvailabilityRepository(api).getAvailability(
        fieldId: const FieldId(3),
        date: DateTime(2026, 11, 20),
      );

      expect(slots.single.startTime.isUtc, isFalse);
      expect(slots.single.startTime, DateTime.utc(2026, 11, 20, 8).toLocal());
    });

    test('dan kada teren ne radi je prazna lista', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'fieldId': 3,
            'date': '2026-11-22',
            'slots': <Object?>[],
          }),
        ),
      );

      expect(
        await HttpAvailabilityRepository(api).getAvailability(
          fieldId: const FieldId(3),
          date: DateTime(2026, 11, 22),
        ),
        isEmpty,
      );
    });

    test('nepoznato stanje termina je greška servera, ne pad', () async {
      final api = clientFor(
        MockClient(
          (request) async => jsonResponse(200, {
            'fieldId': 3,
            'date': '2026-11-20',
            'slots': [slot(8, 'maintenance')],
          }),
        ),
      );

      await expectLater(
        HttpAvailabilityRepository(api).getAvailability(
          fieldId: const FieldId(3),
          date: DateTime(2026, 11, 20),
        ),
        throwsA(
          isA<ServerRejectedException>().having(
            (e) => e.error.code,
            'code',
            ErrorCodes.internal,
          ),
        ),
      );
    });

    test('nepostojeći teren i nema mreže stižu kao izuzeci', () async {
      final notFound = clientFor(
        MockClient(
          (request) async => jsonResponse(404, errorBody('not_found')),
        ),
      );
      final offline = clientFor(
        MockClient(
          (request) async =>
              throw http.ClientException('Connection refused', request.url),
        ),
      );

      await expectLater(
        HttpAvailabilityRepository(notFound).getAvailability(
          fieldId: const FieldId(99),
          date: DateTime(2026, 11, 20),
        ),
        throwsA(isA<ServerRejectedException>()),
      );
      await expectLater(
        HttpAvailabilityRepository(offline).getAvailability(
          fieldId: const FieldId(3),
          date: DateTime(2026, 11, 20),
        ),
        throwsA(isA<ServerUnreachableException>()),
      );
    });
  });

  group('blokade terena preko HTTP-a', () {
    Map<String, Object?> blockJson({int id = 5}) => {
      'id': id,
      'fieldId': 3,
      'startTime': '2026-11-21T08:00:00.000Z',
      'endTime': '2026-11-21T12:00:00.000Z',
      'reason': 'Održavanje',
    };

    test('nova blokada se šalje bez identifikatora, a vraća sa njim', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return jsonResponse(201, blockJson());
        }),
        session: await signedIn(),
      );

      final saved = await HttpScheduleRepository(api).addBlockedPeriod(
        BlockedPeriod(
          fieldId: const FieldId(3),
          startTime: DateTime.utc(2026, 11, 21, 8),
          endTime: DateTime.utc(2026, 11, 21, 12),
          reason: 'Održavanje',
        ),
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/fields/3/blocked-periods');
      expect((jsonDecode(seen.body) as Map).containsKey('id'), isFalse);
      expect(saved.id, const BlockedPeriodId(5));
    });

    test('blokada se briše na adresi svog terena', () async {
      late http.Request seen;
      final api = clientFor(
        MockClient((request) async {
          seen = request;
          return http.Response('', 204);
        }),
        session: await signedIn(),
      );

      await HttpScheduleRepository(api)
          .removeBlockedPeriod(const FieldId(3), const BlockedPeriodId(5));

      expect(seen.method, 'DELETE');
      expect(seen.url.path, '/fields/3/blocked-periods/5');
      expect(seen.headers['authorization'], 'Bearer token-of-ana');
    });

    test('blokada preko potvrđene rezervacije stiže kao razlog, istom porukom kao u domenu', () async {
      final api = clientFor(
        MockClient(
          (request) async =>
              jsonResponse(409, errorBody('block_overlaps_reservation')),
        ),
        session: await signedIn(),
      );

      Object? caught;
      try {
        await HttpScheduleRepository(api).addBlockedPeriod(
          BlockedPeriod(
            fieldId: const FieldId(3),
            startTime: DateTime.utc(2026, 11, 21, 8),
            endTime: DateTime.utc(2026, 11, 21, 12),
          ),
        );
      } catch (error) {
        caught = error;
      }

      expect(
        describeError(caught!),
        const BlockOverlapsConfirmedReservation().message,
      );
    });

    test(
      'tuđa ili nepostojeća blokada: greška servera, ne tihi uspeh',
      () async {
        final api = clientFor(
          MockClient(
            (request) async => jsonResponse(404, errorBody('not_found')),
          ),
          session: await signedIn(),
        );

        await expectLater(
          HttpScheduleRepository(api)
              .removeBlockedPeriod(const FieldId(3), const BlockedPeriodId(99)),
          throwsA(isA<ServerRejectedException>()),
        );
      },
    );
  });
}
