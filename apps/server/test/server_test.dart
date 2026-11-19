@Tags(['db'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:contract/contract.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:relic/relic.dart' show IOAdapter, RelicServer;
import 'package:server/server.dart';
import 'package:server/src/passwords.dart';
import 'package:test/test.dart';

late Pool<void> database;
late RelicServer server;
late Uri base;
late String demoPassword;
late String jwtSecret;
late FakeNotificationGateway notifications;

const testUsers = 10;

Future<String> logIn(String email, {String? password}) async {
  final answer = await http.post(
    base.replace(path: ApiPaths.login),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(LoginRequestDto(email: email, password: password ?? demoPassword).toJson()),
  );
  return SessionDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>).token!;
}

Map<String, String> as(String token) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

Future<int> fieldId(String name) async {
  final answer = await http.get(base.replace(path: ApiPaths.fields, queryParameters: {ApiQuery.limit: '100'}));
  final page = PageDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>, FieldDto.fromJson);
  return page.items.firstWhere((field) => field.name == name).id;
}

DateTime day(int offset, int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset, hour);
}

Future<http.Response> reserve(String token, int field, DateTime start, DateTime end, {Map<String, Object?>? extra}) =>
    http.post(
      base.replace(path: ApiPaths.reservations),
      headers: as(token),
      body: jsonEncode({
        ...CreateReservationRequestDto(fieldId: field, startTime: start, endTime: end).toJson(),
        ...?extra,
      }),
    );

Future<http.Response> act(String token, String path, {Map<String, Object?>? body}) =>
    http.post(base.replace(path: path), headers: as(token), body: body == null ? null : jsonEncode(body));

String codeOf(http.Response response) => ErrorDto.fromJson(jsonDecode(response.body) as Map<String, Object?>).code;

ReservationDto reservationOf(http.Response response) =>
    ReservationDto.fromJson(jsonDecode(response.body) as Map<String, Object?>);

Future<void> migrateWithDbmate(Uri databaseUrl) async {
  final insideCompose = databaseUrl.replace(host: 'db', port: 5432, path: '/terenzo_test');
  final result = await Process.run('docker', [
    'compose',
    'run',
    '--rm',
    '-e',
    'DATABASE_URL=$insideCompose',
    'migrate',
  ], workingDirectory: '../..');
  if (result.exitCode != 0) throw StateError('dbmate failed: ${result.stderr}');
}

void main() {
  setUpAll(() async {
    final config = ServerConfig.fromEnvironment(serverEnvironment());
    demoPassword = config.demoPassword!;
    jwtSecret = config.jwtSecret;
    final admin = Pool<void>.withUrl(config.databaseUrl);
    await admin.execute('DROP DATABASE IF EXISTS terenzo_test WITH (FORCE)');
    await admin.execute('CREATE DATABASE terenzo_test');
    await admin.close();
    database = Pool<void>.withUrl(Uri.parse(config.databaseUrl).replace(path: '/terenzo_test').toString());
    await migrateWithDbmate(Uri.parse(config.databaseUrl));
    await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);
    final hash = await hashPassword(demoPassword);
    for (var n = 1; n <= testUsers; n++) {
      await database.execute(
        Sql.named('''
          INSERT INTO users (first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
          VALUES ('Test', @n, @email, '060', '2000-01-01', 'user', @hash)
        '''),
        parameters: {'n': '$n', 'email': 'test$n@terenzo.rs', 'hash': hash},
      );
    }
    notifications = FakeNotificationGateway(apiKey: 'test-key', log: (_) {});
    final handlers = TerenzoHandlers(terenzo: PostgresTerenzo(database), notifications: notifications);
    final sessions = SessionHandlers(store: TerenzoStore(database), secret: jwtSecret, ttl: const Duration(hours: 1));
    server = RelicServer(() => IOAdapter.bind(InternetAddress.loopbackIPv4, port: 0));
    await server.mountAndStart(buildHandler(handlers, sessions, corsOrigins: const ['http://localhost:8081']));
    base = Uri.parse('http://localhost:${server.port}');
  });

  tearDownAll(() async {
    await server.close();
    await database.close();
  });

  group('početni podaci', () {
    // Ova grupa ide prva, dok u bazi ima samo ono što je upisao `seedDemoData`.
    test('the database has at least 10 reservations and every one of the 4 states', () async {
      final rows = await database.execute(
        "SELECT status, count(*) FROM reservations GROUP BY status",
      );
      final byStatus = {for (final row in rows) row[0]! as String: row[1]! as int};

      expect(byStatus.values.fold<int>(0, (sum, count) => sum + count), greaterThanOrEqualTo(10));
      expect(byStatus.keys, containsAll(['pending', 'confirmed', 'completed', 'cancelled']));
    });

    test('there is an account for each role and at least two for the mobile app', () async {
      final rows = await database.execute('SELECT role, count(*) FROM users GROUP BY role');
      final byRole = {for (final row in rows) row[0]! as String: row[1]! as int};

      expect(byRole['admin'], greaterThanOrEqualTo(1));
      expect(byRole['owner'], greaterThanOrEqualTo(1));
      expect(byRole['user'], greaterThanOrEqualTo(2));
    });

    test('every demo account from the README exists and can log in', () async {
      for (final account in demoAccounts) {
        final token = await logIn(account.email);
        expect(token, isNotEmpty, reason: account.email);
      }
    });

    test('passwords are stored only as hashes, never as plain text', () async {
      final rows = await database.execute('SELECT email, password_hash FROM users');

      for (final row in rows) {
        final hash = row[1]! as String;
        expect(hash, isNot(demoPassword), reason: row[0]! as String);
        expect(hash, isNot(contains(demoPassword)), reason: row[0]! as String);
        expect(hash, startsWith(r'$argon2id$'), reason: row[0]! as String);
      }
    });

    test('the seed runs only on an empty database, so a restart does not duplicate anything', () async {
      final before = await database.execute('SELECT count(*) FROM users');

      await seedDemoData(database, now: DateTime.now(), demoPassword: demoPassword);

      final after = await database.execute('SELECT count(*) FROM users');
      expect(after.single[0], before.single[0]);
    });
  });

  group('pravila na serveru', () {
    test('ten users book the same slot at the same moment: the database lets exactly one in', () async {
      final arena = await fieldId('Arena Fudbal');
      final tokens = [for (var n = 1; n <= testUsers; n++) await logIn('test$n@terenzo.rs')];

      final answers = await Future.wait([
        for (final token in tokens) reserve(token, arena, day(10, 18), day(10, 19)),
      ]);

      expect(answers.where((a) => a.statusCode == 201), hasLength(1));
      final refused = answers.where((a) => a.statusCode != 201).toList();
      expect(refused, hasLength(testUsers - 1));
      expect(refused.map((a) => a.statusCode).toSet(), {409});
      expect(refused.map(codeOf).toSet(), {ErrorCodes.slotTaken});
    });

    test('one user books the same hour on two fields from two devices at once: one booking is kept', () async {
      final token = await logIn('korisnik3@terenzo.rs');
      final arena = await fieldId('Arena Fudbal');
      final basket = await fieldId('Basket Park');

      final answers = await Future.wait([
        reserve(token, arena, day(11, 12), day(11, 13)),
        reserve(token, basket, day(11, 12), day(11, 13)),
      ]);

      expect(answers.map((a) => a.statusCode).toList()..sort(), [201, 409]);
    });

    test('a call around the app that breaks a rule is refused with the same code as in the app', () async {
      final token = await logIn('korisnik2@terenzo.rs');
      final tennis = await fieldId('Tenis Centar');
      final arena = await fieldId('Arena Fudbal');

      final outside = await reserve(token, tennis, day(12, 6), day(12, 7));
      final past = await reserve(token, tennis, day(-1, 10), day(-1, 11));
      final backwards = await reserve(token, tennis, day(12, 11), day(12, 10));
      final blocked = await reserve(token, arena, day(7, 9), day(7, 10));

      expect((outside.statusCode, codeOf(outside)), (422, ErrorCodes.outsideWorkingHours));
      expect((past.statusCode, codeOf(past)), (422, ErrorCodes.reservationInPast));
      expect((backwards.statusCode, codeOf(backwards)), (422, ErrorCodes.invalidTimeRange));
      expect((blocked.statusCode, codeOf(blocked)), (422, ErrorCodes.fieldBlocked));
    });

    test('cancelling less than 5 hours before the start is refused with the limit in the error', () async {
      final token = await logIn('korisnik2@terenzo.rs');
      final soon = DateTime.now().add(const Duration(hours: 3));
      final rows = await database.execute(
        Sql.named('''
          INSERT INTO reservations (field_id, user_id, start_time, end_time, total_price, status, checked_in_at)
          SELECT f.id, u.id, @start, @end, 2000, 'confirmed', @checkedIn
          FROM sports_fields f, users u WHERE f.name = 'Tenis Centar' AND u.email = 'korisnik2@terenzo.rs'
          RETURNING id
        '''),
        parameters: {
          'start': soon.toUtc(),
          'end': soon.add(const Duration(hours: 1)).toUtc(),
          'checkedIn': soon.subtract(const Duration(hours: 6)).toUtc(),
        },
      );

      final answer = await act(token, ApiPaths.cancelReservation(rows.single[0]! as int));

      expect(answer.statusCode, 422);
      final error = ErrorDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>);
      expect(error.code, ErrorCodes.cancellationDeadlineExpired);
      expect(error.detailInt(ErrorDetailKeys.hours), 5);
    });

    test('two owners acting on the same reservation at once: one wins, the other is told it already changed', () async {
      final user = await logIn('korisnik1@terenzo.rs');
      final owner = await logIn('vlasnik1@terenzo.rs');
      final created = reservationOf(await reserve(user, await fieldId('Arena Fudbal'), day(13, 15), day(13, 16)));

      final answers = await Future.wait([
        act(owner, ApiPaths.confirmReservation(created.id)),
        act(owner, ApiPaths.rejectReservation(created.id), body: {'reason': 'Turnir'}),
      ]);

      expect(answers.map((a) => a.statusCode).toList()..sort(), [200, 409]);
      expect(codeOf(answers.firstWhere((a) => a.statusCode == 409)), ErrorCodes.invalidStatusTransition);
    });

    test('a refused booking leaves the slot free for the next user after a reload', () async {
      final first = await logIn('test1@terenzo.rs');
      final tennis = await fieldId('Tenis Centar');
      final created = reservationOf(await reserve(first, tennis, day(14, 11), day(14, 12)));
      await act(first, ApiPaths.cancelReservation(created.id));

      final again = await reserve(await logIn('test2@terenzo.rs'), tennis, day(14, 11), day(14, 12));

      expect(again.statusCode, 201);
    });
  });

  group('korisnici i uloge', () {
    test('a mobile user confirming or rejecting around the app is refused', () async {
      final user = await logIn('korisnik1@terenzo.rs');
      final created = reservationOf(await reserve(user, await fieldId('Arena Fudbal'), day(15, 10), day(15, 11)));

      final confirm = await act(user, ApiPaths.confirmReservation(created.id));
      final reject = await act(user, ApiPaths.rejectReservation(created.id));

      expect((confirm.statusCode, codeOf(confirm)), (403, ErrorCodes.forbidden));
      expect((reject.statusCode, codeOf(reject)), (403, ErrorCodes.forbidden));
    });

    test('the owner of the field sees who booked, and the user sees his own reservation without that block', () async {
      final user = await logIn('korisnik1@terenzo.rs');
      final owner = await logIn('vlasnik1@terenzo.rs');
      final created = reservationOf(await reserve(user, await fieldId('Arena Fudbal'), day(16, 10), day(16, 11)));

      final seenByUser = await http.get(base.replace(path: ApiPaths.reservation(created.id)), headers: as(user));
      final seenByOwner = await http.get(base.replace(path: ApiPaths.reservation(created.id)), headers: as(owner));
      final listedForOwner = await http.get(
        base.replace(path: ApiPaths.reservations, queryParameters: {ApiQuery.limit: '100'}),
        headers: as(owner),
      );

      expect(reservationOf(seenByUser).customer, isNull);
      final customer = reservationOf(seenByOwner).customer!;
      expect((customer.firstName, customer.lastName, customer.email), ('Ana', 'Anić', 'korisnik1@terenzo.rs'));
      expect(customer.phoneNumber, isNotNull);
      final page = PageDto.fromJson(jsonDecode(listedForOwner.body) as Map<String, Object?>, ReservationDto.fromJson);
      expect(page.items.every((r) => r.customer != null), isTrue);
    });

    test('a user cannot see or cancel another user’s reservation', () async {
      final ana = await logIn('korisnik1@terenzo.rs');
      final marko = await logIn('korisnik2@terenzo.rs');
      final created = reservationOf(await reserve(ana, await fieldId('Tenis Centar'), day(15, 14), day(15, 15)));

      final cancel = await act(marko, ApiPaths.cancelReservation(created.id));
      final read = await http.get(base.replace(path: ApiPaths.reservation(created.id)), headers: as(marko));

      expect((cancel.statusCode, codeOf(cancel)), (404, ErrorCodes.notFound));
      expect(read.statusCode, 404);
    });

    test('an owner cannot change another owner’s field', () async {
      final milica = await logIn('vlasnik2@terenzo.rs');
      final arena = await fieldId('Arena Fudbal');
      final current = FieldDto.fromJson(
        jsonDecode((await http.get(base.replace(path: ApiPaths.field(arena)))).body) as Map<String, Object?>,
      );

      final answer = await http.patch(
        base.replace(path: ApiPaths.field(arena)),
        headers: as(milica),
        body: jsonEncode({...current.toJson(), 'pricePerHour': 1}),
      );

      expect((answer.statusCode, codeOf(answer)), (403, ErrorCodes.forbidden));
    });

    test('the server takes the user from the token, not from the request body', () async {
      final ana = await logIn('korisnik1@terenzo.rs');
      final created = reservationOf(
        await reserve(ana, await fieldId('Basket Park'), day(16, 10), day(16, 11), extra: {'userId': 999}),
      );
      final me = SessionDto.fromJson(
        jsonDecode((await http.get(base.replace(path: ApiPaths.me), headers: as(ana))).body) as Map<String, Object?>,
      );

      expect(created.userId, me.user.id);
    });

    test('each user sees only their own reservations, an owner only those on their fields', () async {
      final ana = await logIn('korisnik1@terenzo.rs');
      final milica = await logIn('vlasnik2@terenzo.rs');
      Future<List<ReservationDto>> list(String token) async => PageDto.fromJson(
        jsonDecode((await http.get(base.replace(path: ApiPaths.reservations, queryParameters: {ApiQuery.limit: '100'}), headers: as(token))).body)
            as Map<String, Object?>,
        ReservationDto.fromJson,
      ).items;
      final me = SessionDto.fromJson(
        jsonDecode((await http.get(base.replace(path: ApiPaths.me), headers: as(ana))).body) as Map<String, Object?>,
      );
      final tennis = await fieldId('Tenis Centar');

      expect((await list(ana)).every((r) => r.userId == me.user.id), isTrue);
      expect((await list(milica)).every((r) => r.fieldId == tennis), isTrue);
    });

    test('wrong password and unknown account give the same answer', () async {
      Future<http.Response> attempt(String email, String password) => http.post(
        base.replace(path: ApiPaths.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(LoginRequestDto(email: email, password: password).toJson()),
      );

      final wrong = await attempt('korisnik1@terenzo.rs', 'pogresna');
      final unknown = await attempt('nema@terenzo.rs', demoPassword);

      expect((wrong.statusCode, codeOf(wrong)), (401, ErrorCodes.invalidCredentials));
      expect((unknown.statusCode, codeOf(unknown)), (401, ErrorCodes.invalidCredentials));
    });

    test('no token, a forged token and an expired token are told apart', () async {
      final token = await logIn('korisnik1@terenzo.rs');
      final me = base.replace(path: ApiPaths.me);
      final expired = JWT(
        {'role': 'user', 'iat': 1, 'exp': 2},
        subject: '1',
      ).sign(SecretKey(jwtSecret), algorithm: JWTAlgorithm.HS256, noIssueAt: true);

      final none = await http.get(me);
      final forged = await http.get(me, headers: as('${token.substring(0, token.length - 2)}xx'));
      final old = await http.get(me, headers: as(expired));

      expect((none.statusCode, codeOf(none)), (401, ErrorCodes.unauthenticated));
      expect((forged.statusCode, codeOf(forged)), (401, ErrorCodes.invalidToken));
      expect((old.statusCode, codeOf(old)), (401, ErrorCodes.tokenExpired));
    });

    test('only the admin approves a field, and then it shows in the public catalog', () async {
      final owner = await logIn('vlasnik2@terenzo.rs');
      final admin = await logIn('admin@terenzo.rs');
      final waiting = PageDto.fromJson(
        jsonDecode((await http.get(base.replace(path: ApiPaths.fieldsAwaitingApproval), headers: as(admin))).body)
            as Map<String, Object?>,
        FieldDto.fromJson,
      ).items.single;

      final byOwner = await act(owner, ApiPaths.fieldReview(waiting.id), body: {'decision': 'approved'});
      final byAdmin = await act(admin, ApiPaths.fieldReview(waiting.id), body: {'decision': 'approved'});

      expect((byOwner.statusCode, codeOf(byOwner)), (403, ErrorCodes.forbidden));
      expect(byAdmin.statusCode, 200);
      expect(await fieldId('Padel Klub'), waiting.id);
    });

    test('confirming a reservation sends the notification through the port', () async {
      final user = await logIn('korisnik2@terenzo.rs');
      final owner = await logIn('vlasnik1@terenzo.rs');
      final created = reservationOf(await reserve(user, await fieldId('Arena Fudbal'), day(17, 10), day(17, 11)));
      final before = notifications.sent.length;

      final answer = await act(owner, ApiPaths.confirmReservation(created.id));

      expect(reservationOf(answer).status, ReservationStatusCodes.confirmed);
      expect(notifications.sent.length, before + 1);
      expect(notifications.sent.last.recipient.email, 'korisnik2@terenzo.rs');
    });
  });

  group('blokiranje termina', () {
    test('an owner blocks and unblocks a slot; a block over a confirmed reservation is refused', () async {
      final owner = await logIn('vlasnik1@terenzo.rs');
      final user = await logIn('korisnik2@terenzo.rs');
      final basket = await fieldId('Basket Park');
      final booked = reservationOf(await reserve(user, basket, day(18, 18), day(18, 19)));
      expect(booked.status, ReservationStatusCodes.confirmed);

      final overBooking = await act(
        owner,
        ApiPaths.blockedPeriods(basket),
        body: CreateBlockedPeriodRequestDto(startTime: day(18, 17), endTime: day(18, 20), reason: 'Turnir').toJson(),
      );
      final free = await act(
        owner,
        ApiPaths.blockedPeriods(basket),
        body: CreateBlockedPeriodRequestDto(startTime: day(18, 8), endTime: day(18, 10), reason: 'Održavanje').toJson(),
      );
      final block = BlockedPeriodDto.fromJson(jsonDecode(free.body) as Map<String, Object?>);
      final reserveBlocked = await reserve(user, basket, day(18, 9), day(18, 10));
      final removed = await http.delete(base.replace(path: ApiPaths.blockedPeriod(basket, block.id!)), headers: as(owner));
      final afterRemoval = await reserve(user, basket, day(18, 9), day(18, 10));

      expect((overBooking.statusCode, codeOf(overBooking)), (409, ErrorCodes.blockOverlapsReservation));
      expect(free.statusCode, 201);
      expect(codeOf(reserveBlocked), ErrorCodes.fieldBlocked);
      expect(removed.statusCode, 204);
      expect(afterRemoval.statusCode, 201);
    });
  });

  group('nalozi za administratora', () {
    Future<int> idOf(String token) async {
      final answer = await http.get(base.replace(path: ApiPaths.me), headers: as(token));
      return SessionDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>).user.id;
    }

    Future<http.Response> setActive(String token, int id, {required bool active}) => http.patch(
      base.replace(path: ApiPaths.user(id)),
      headers: as(token),
      body: jsonEncode(SetUserActiveRequestDto(isActive: active).toJson()),
    );

    Future<http.Response> tryLogIn(String email) => http.post(
      base.replace(path: ApiPaths.login),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(LoginRequestDto(email: email, password: demoPassword).toJson()),
    );

    Future<String> addUser(String email) async {
      await database.execute(
        Sql.named('''
          INSERT INTO users (first_name, last_name, email, phone_number, date_of_birth, role, password_hash)
          VALUES ('Za', 'Gašenje', @email, '060', '2000-01-01', 'user', @hash)
        '''),
        parameters: {'email': email, 'hash': await hashPassword(demoPassword)},
      );
      return email;
    }

    test('an owner and a user get 403 on the list of accounts, an administrator gets all of them', () async {
      final owner = await http.get(base.replace(path: ApiPaths.users), headers: as(await logIn('vlasnik1@terenzo.rs')));
      final user = await http.get(base.replace(path: ApiPaths.users), headers: as(await logIn('korisnik1@terenzo.rs')));
      final admin = await http.get(
        base.replace(path: ApiPaths.users, queryParameters: {ApiQuery.limit: '100'}),
        headers: as(await logIn('admin@terenzo.rs')),
      );

      expect((owner.statusCode, codeOf(owner)), (403, ErrorCodes.forbidden));
      expect((user.statusCode, codeOf(user)), (403, ErrorCodes.forbidden));
      expect(admin.statusCode, 200);
      final page = PageDto.fromJson(jsonDecode(admin.body) as Map<String, Object?>, UserDto.fromJson);
      expect(page.items.map((u) => u.role).toSet(), containsAll(['user', 'owner', 'admin']));
      expect(page.items.every((u) => u.isActive == true && u.phoneNumber != null), isTrue);
    });

    test('a deactivated account cannot log in, and the session it had stops working at once', () async {
      final email = await addUser('gasenje1@terenzo.rs');
      final admin = await logIn('admin@terenzo.rs');
      final token = await logIn(email);
      final id = await idOf(token);

      final off = await setActive(admin, id, active: false);
      final login = await tryLogIn(email);
      final old = await http.get(base.replace(path: ApiPaths.me), headers: as(token));

      expect(off.statusCode, 200);
      expect(UserDto.fromJson(jsonDecode(off.body) as Map<String, Object?>).isActive, isFalse);
      expect((login.statusCode, codeOf(login)), (403, ErrorCodes.accountDeactivated));
      expect((old.statusCode, codeOf(old)), (401, ErrorCodes.accountDeactivated));
    });

    test('a wrong password on a deactivated account does not reveal that it is deactivated', () async {
      final email = await addUser('gasenje2@terenzo.rs');
      final admin = await logIn('admin@terenzo.rs');
      await setActive(admin, await idOf(await logIn(email)), active: false);

      final answer = await http.post(
        base.replace(path: ApiPaths.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(LoginRequestDto(email: email, password: 'pogresna-lozinka').toJson()),
      );

      expect((answer.statusCode, codeOf(answer)), (401, ErrorCodes.invalidCredentials));
    });

    test('an account that is activated again can log in', () async {
      final email = await addUser('gasenje3@terenzo.rs');
      final admin = await logIn('admin@terenzo.rs');
      final id = await idOf(await logIn(email));
      await setActive(admin, id, active: false);

      final on = await setActive(admin, id, active: true);
      final login = await tryLogIn(email);

      expect(on.statusCode, 200);
      expect(login.statusCode, 200);
    });

    test('only an administrator deactivates, and not their own account', () async {
      final admin = await logIn('admin@terenzo.rs');
      final victim = await idOf(await logIn('korisnik3@terenzo.rs'));

      final byOwner = await setActive(await logIn('vlasnik1@terenzo.rs'), victim, active: false);
      final byUser = await setActive(await logIn('korisnik1@terenzo.rs'), victim, active: false);
      final own = await setActive(admin, await idOf(admin), active: false);
      final unknown = await setActive(admin, 999999, active: false);
      final stillIn = await tryLogIn('korisnik3@terenzo.rs');

      expect((byOwner.statusCode, codeOf(byOwner)), (403, ErrorCodes.forbidden));
      expect((byUser.statusCode, codeOf(byUser)), (403, ErrorCodes.forbidden));
      expect((own.statusCode, codeOf(own)), (403, ErrorCodes.forbidden));
      expect((unknown.statusCode, codeOf(unknown)), (404, ErrorCodes.notFound));
      expect(stillIn.statusCode, 200);
    });
  });

  group('ugovor i pregledač', () {
    test('the public catalog works without signing in and pages with total', () async {
      final answer = await http.get(base.replace(path: ApiPaths.fields, queryParameters: {ApiQuery.limit: '2'}));
      final page = PageDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>, FieldDto.fromJson);

      expect(answer.statusCode, 200);
      expect(page.items, hasLength(2));
      expect(page.total, greaterThan(2));
      expect(page.hasMore, isTrue);
    });

    test('free slots for a day come from the schedule and the bookings in the database', () async {
      final arena = await fieldId('Arena Fudbal');
      final date = day(7, 0);
      final answer = await http.get(
        base.replace(
          path: ApiPaths.availability(arena),
          queryParameters: {ApiQuery.date: dateToJson(date.year, date.month, date.day)},
        ),
      );
      final availability = AvailabilityDto.fromJson(jsonDecode(answer.body) as Map<String, Object?>);

      expect(availability.slots.first.state, SlotStateCodes.blocked);
      expect(availability.slots.last.state, SlotStateCodes.free);
    });

    test('a browser page from a foreign origin cannot change data', () async {
      final answer = await http.post(
        base.replace(path: ApiPaths.login),
        headers: {'Content-Type': 'application/json', 'Origin': 'https://evil.example'},
        body: jsonEncode(LoginRequestDto(email: 'korisnik1@terenzo.rs', password: demoPassword).toJson()),
      );
      final allowed = await http.get(
        base.replace(path: ApiPaths.fields),
        headers: {'Origin': 'http://localhost:8081'},
      );

      expect(answer.statusCode, 403);
      expect(allowed.headers['access-control-allow-origin'], 'http://localhost:8081');
    });

    test('an unknown route answers with the error format of the contract', () async {
      final answer = await http.get(base.replace(path: '/nema'));

      expect((answer.statusCode, codeOf(answer)), (404, ErrorCodes.notFound));
    });
  });
}
