import 'dart:async';
import 'dart:convert';

import 'package:api_client/api_client.dart';
import 'package:contract/contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:messages/messages.dart';
import 'package:mobile/data/mobile_server.dart';
import 'package:mobile/main.dart';
import 'package:mobile/server_address.dart';

/// Server u memoriji: odgovara kao pravi, preko istog ugovora (`contract`), a
/// može da se „ugasi“ i da jednom odbije rezervaciju kao da je termin zauzet.
final class _Server {
  bool down = false;

  /// Koliko sledećih rezervacija server odbija sa `slot_taken`.
  int refuseBookings = 0;

  /// Poziv koji nikad ne odgovara (server visi).
  Completer<http.Response>? hang;

  final log = <String>[];
  final reservations = <ReservationDto>[];
  final takenHours = <int>{};

  static final user = UserDto(
    id: 5,
    firstName: 'Marko',
    lastName: 'Marić',
    email: 'marko@example.com',
    role: 'user',
  );

  static final fields = [
    for (final (id, name, price) in [
      (1, 'Arena Fudbal', 3500),
      (2, 'Tenis Centar', 2000),
    ])
      FieldDto(
        id: id,
        ownerId: 9,
        name: name,
        description: 'Opis',
        sport: id == 1 ? 'football' : 'tennis',
        address: 'Ulica $id',
        city: 'Beograd',
        pricePerHour: price,
        contactPhone: '060',
        confirmationMode: 'automatic',
        isActive: true,
        approvalStatus: 'approved',
      ),
  ];

  int count(String request) => log.where((entry) => entry == request).length;

  http.Client get client => MockClient(_handle);

  static http.Response _json(int status, Object? body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static Map<String, Object?> _page(List<Map<String, Object?>> items) => {
    'items': items,
    'total': items.length,
    'limit': ApiPaging.maxLimit,
    'offset': 0,
  };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    log.add('${request.method} $path');

    if (down) throw http.ClientException('Connection refused', request.url);
    final pending = hang;
    if (pending != null) return pending.future;

    if (request.method == 'GET' && path == ApiPaths.fields) {
      return _json(200, _page([for (final f in fields) f.toJson()]));
    }
    if (request.method == 'GET' && path == ApiPaths.me) {
      return _json(
        200,
        SessionDto(
          user: user,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
        ).toJson(),
      );
    }
    for (final field in fields) {
      if (request.method == 'GET' && path == ApiPaths.field(field.id)) {
        return _json(200, field.toJson());
      }
      if (request.method == 'GET' && path == ApiPaths.schedule(field.id)) {
        return _json(
          200,
          ScheduleDto(
            days: [
              for (final day in [
                WeekDayCodes.monday,
                WeekDayCodes.tuesday,
                WeekDayCodes.wednesday,
                WeekDayCodes.thursday,
                WeekDayCodes.friday,
                WeekDayCodes.saturday,
                WeekDayCodes.sunday,
              ])
                ScheduleDayDto(
                  dayOfWeek: day,
                  opensAt: const ClockTime(8, 0),
                  closesAt: const ClockTime(23, 0),
                ),
            ],
          ).toJson(),
        );
      }
      if (request.method == 'GET' &&
          path == ApiPaths.blockedPeriods(field.id)) {
        return _json(200, _page(const []));
      }
      if (request.method == 'GET' && path == ApiPaths.availability(field.id)) {
        final date = DateTime.parse(
          request.url.queryParameters[ApiQuery.date]!,
        );
        return _json(
          200,
          AvailabilityDto(
            fieldId: field.id,
            date: request.url.queryParameters[ApiQuery.date]!,
            slots: [
              for (var hour = 8; hour < 23; hour++)
                SlotDto(
                  startTime: DateTime(
                    date.year,
                    date.month,
                    date.day,
                    hour,
                  ).toUtc(),
                  endTime: DateTime(
                    date.year,
                    date.month,
                    date.day,
                    hour + 1,
                  ).toUtc(),
                  state: takenHours.contains(hour)
                      ? SlotStateCodes.taken
                      : SlotStateCodes.free,
                ),
            ],
          ).toJson(),
        );
      }
    }
    if (request.method == 'GET' && path == ApiPaths.reservations) {
      return _json(200, _page([for (final r in reservations) r.toJson()]));
    }
    if (request.method == 'POST' && path == ApiPaths.reservations) {
      final body = CreateReservationRequestDto.fromJson(
        jsonDecode(request.body) as Map<String, Object?>,
      );
      if (refuseBookings > 0) {
        refuseBookings--;
        // Neko drugi je upravo rezervisao taj termin.
        takenHours.add(body.startTime.toLocal().hour);
        return _json(409, const ErrorDto(code: ErrorCodes.slotTaken).toJson());
      }
      final created = ReservationDto(
        id: reservations.length + 1,
        fieldId: body.fieldId,
        userId: user.id,
        startTime: body.startTime,
        endTime: body.endTime,
        totalPrice: 3500,
        status: 'confirmed',
        paymentStatus: 'unpaid',
        createdAt: DateTime.now().toUtc(),
      );
      reservations.add(created);
      return _json(201, created.toJson());
    }

    return _json(404, const ErrorDto(code: ErrorCodes.notFound).toJson());
  }
}

void main() {
  final today = DateUtils.dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));

  late _Server server;
  late MobileServer mobile;

  /// Aplikacija nad HTTP repozitorijumima, bez ijedne izmene ekrana ili Bloc-a.
  Future<void> pumpApp(
    WidgetTester tester, {
    String location = '/fields',
    bool signedIn = true,
    Duration timeout = const Duration(seconds: 5),
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = MemorySessionStore();
    if (signedIn) await session.write('token-of-marko');

    mobile = MobileServer.connect(
      baseUri: Uri.parse('http://localhost:8080'),
      session: session,
      httpClient: server.client,
      timeout: timeout,
    );
    addTearDown(mobile.close);

    await tester.pumpWidget(
      MyApp(
        repository: mobile.reservations,
        availabilityRepository: mobile.availability,
        fieldRepository: mobile.fields,
        scheduleRepository: mobile.schedules,
        authRepository: mobile.auth,
        initialLocation: location,
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  String reserve(
    int fieldId,
    DateTime day, {
    String start = '12:00',
    String end = '13:00',
  }) => Uri(
    path: '/fields/$fieldId/reserve',
    queryParameters: {
      'date': day.toIso8601String(),
      'start': start,
      'end': end,
    },
  ).toString();

  setUp(() => server = _Server());

  group('adresa servera', () {
    test('zadata adresa ima prednost', () {
      expect(
        serverAddress(
          configured: 'http://192.168.0.5:8080',
          platform: TargetPlatform.android,
        ),
        Uri.parse('http://192.168.0.5:8080'),
      );
    });

    test('Android emulator vidi računar na 10.0.2.2', () {
      expect(
        serverAddress(
          configured: '',
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        Uri.parse('http://10.0.2.2:8080'),
      );
    });

    test('ostale platforme i veb koriste localhost', () {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      ]) {
        expect(
          serverAddress(configured: '', platform: platform, isWeb: false),
          Uri.parse('http://localhost:8080'),
        );
      }
      expect(
        serverAddress(
          configured: '',
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        Uri.parse('http://localhost:8080'),
      );
    });
  });

  group('tereni sa servera', () {
    testWidgets('katalog se čita sa servera, bez prijave', (tester) async {
      await pumpApp(tester, signedIn: false);

      expect(find.text('Arena Fudbal'), findsOneWidget);
      expect(find.text('Tenis Centar'), findsOneWidget);
      expect(server.count('GET /fields'), 1);
      // Katalog je javan: bez prijave se ništa drugo ne traži.
      expect(server.log, isNot(contains('GET /reservations')));
    });

    testWidgets(
      'server ne radi: poruka i „Pokušaj ponovo“, bez beskonačnog učitavanja',
      (tester) async {
        server.down = true;
        await pumpApp(tester, signedIn: false);

        expect(find.text(serverUnreachableMessage), findsOneWidget);
        expect(find.text('Pokušaj ponovo'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('server se vrati: „Pokušaj ponovo“ učitava terene', (
      tester,
    ) async {
      server.down = true;
      await pumpApp(tester, signedIn: false);

      server.down = false;
      await tester.tap(find.text('Pokušaj ponovo'));
      await tester.pumpAndSettle();

      expect(find.text('Arena Fudbal'), findsOneWidget);
      expect(find.text(serverUnreachableMessage), findsNothing);
    });

    testWidgets(
      'server koji ne odgovara: posle isteka vremena je poruka, ne vrtlog',
      (tester) async {
        server.hang = Completer<http.Response>();
        await pumpApp(
          tester,
          signedIn: false,
          timeout: const Duration(milliseconds: 300),
          settle: false,
        );
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text(serverUnreachableMessage), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('rezervisanje nad serverom', () {
    testWidgets('uspešna rezervacija se šalje serveru i vidi se u spisku', (
      tester,
    ) async {
      await pumpApp(tester, location: reserve(1, tomorrow));

      await tester.tap(find.text('Potvrdi rezervaciju'));
      await tester.pumpAndSettle();

      expect(find.text('Nova rezervacija'), findsNothing);
      expect(find.text('Rezervacija je uspešno kreirana!'), findsOneWidget);
      expect(server.count('POST /reservations'), 1);
      expect(server.reservations, hasLength(1));
      // Prijava je sa tokenom koji je klijent čuvao: nalog dolazi sa servera.
      expect(server.count('GET /auth/me'), 1);
    });

    testWidgets(
      'odbijen termin: razlog, osveženi podaci, pa drugi termin uspeva',
      (tester) async {
        await pumpApp(tester, location: reserve(1, tomorrow));
        server.refuseBookings = 1;
        final before = server.count('GET /fields/1/schedule');

        await tester.tap(find.text('Potvrdi rezervaciju'));
        await tester.pumpAndSettle();

        // Isti razlog kao kada bi pravilo proverio klijent, a forma ostaje sa unosom.
        expect(
          find.text('Termin se preklapa sa postojećom rezervacijom.'),
          findsWidgets,
        );
        expect(find.text('Nova rezervacija'), findsOneWidget);
        expect(find.widgetWithText(TextField, '12:00'), findsOneWidget);
        // Posle odbijanja klijent ponovo čita radno vreme, blokade i svoje
        // rezervacije, da forma ne ostane sa starim podacima.
        expect(server.count('GET /fields/1/schedule'), greaterThan(before));
        expect(server.reservations, isEmpty);

        await tester.enterText(find.byType(TextField).at(0), '18:00');
        await tester.enterText(find.byType(TextField).at(1), '19:00');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Potvrdi rezervaciju'));
        await tester.pumpAndSettle();

        expect(find.text('Nova rezervacija'), findsNothing);
        expect(server.reservations, hasLength(1));
      },
    );

    testWidgets(
      'server ugašen pri slanju: poruka, unos ostaje, ponovno slanje radi',
      (tester) async {
        await pumpApp(tester, location: reserve(1, tomorrow));

        server.down = true;
        await tester.tap(find.text('Potvrdi rezervaciju'));
        await tester.pumpAndSettle();

        expect(find.text(serverUnreachableMessage), findsWidgets);
        expect(find.text('Nova rezervacija'), findsOneWidget);

        server.down = false;
        await tester.tap(find.text('Potvrdi rezervaciju'));
        await tester.pumpAndSettle();

        expect(find.text('Nova rezervacija'), findsNothing);
        expect(server.reservations, hasLength(1));
      },
    );
  });

  group('rezervacije sa servera', () {
    testWidgets('spisak dolazi sa servera', (tester) async {
      server.reservations.add(
        ReservationDto(
          id: 1,
          fieldId: 1,
          userId: 5,
          startTime: DateTime.now().toUtc().add(const Duration(days: 3)),
          endTime: DateTime.now().toUtc().add(
            const Duration(days: 3, hours: 1),
          ),
          totalPrice: 3500,
          status: 'confirmed',
          paymentStatus: 'unpaid',
          createdAt: DateTime.now().toUtc(),
        ),
      );
      await pumpApp(tester, location: '/reservations');

      expect(find.text('Arena Fudbal'), findsWidgets);
      expect(server.count('GET /reservations'), greaterThanOrEqualTo(1));
    });
  });
}
