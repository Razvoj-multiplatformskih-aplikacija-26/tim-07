import 'dart:convert';

import 'package:contract/contract.dart';
import 'package:test/test.dart';

/// Šalje DTO kroz pravi JSON tekst i nazad, kao što to rade mreža i server.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

final reservationJson = <String, Object?>{
  'id': 7,
  'fieldId': 3,
  'userId': 2,
  'startTime': '2026-11-20T17:00:00.000Z',
  'endTime': '2026-11-20T18:30:00.000Z',
  'totalPrice': 4500,
  'status': 'pending',
  'paymentStatus': 'unpaid',
  'createdAt': '2026-11-17T09:15:00.000Z',
};

void main() {
  group('rezervacija', () {
    test('prolazi kroz JSON i nazad bez gubitka', () {
      final dto = ReservationDto.fromJson(reservationJson);

      expect(dto.startTime, DateTime.utc(2026, 11, 20, 17));
      expect(
        dto.endTime.difference(dto.startTime),
        const Duration(minutes: 90),
      );
      expect(dto.totalPrice, 4500);
      expect(wire(dto.toJson()), reservationJson);
    });

    test('opciona polja se ne šalju kada ih nema', () {
      final json = ReservationDto.fromJson(reservationJson).toJson();

      expect(json.containsKey('checkedInAt'), isFalse);
      expect(json.containsKey('cancellationReason'), isFalse);
    });

    test(
      'stariji klijent čita odgovor novijeg servera sa nepoznatim poljem',
      () {
        final dto = ReservationDto.fromJson({
          ...reservationJson,
          'parking': true,
        });

        expect(dto.id, 7);
      },
    );

    test('nepoznato stanje prolazi neoštećeno i ne obara klijenta', () {
      final dto = ReservationDto.fromJson({
        ...reservationJson,
        'status': 'no_show',
      });

      expect(dto.status, 'no_show');
      expect(wire(dto.toJson())['status'], 'no_show');
    });

    test('obavezno polje koje fali daje FormatException', () {
      expect(
        () =>
            ReservationDto.fromJson({...reservationJson}..remove('startTime')),
        throwsFormatException,
      );
    });

    test('novac kao tekst ili decimalni broj se odbija', () {
      expect(
        () =>
            ReservationDto.fromJson({...reservationJson, 'totalPrice': '4500'}),
        throwsFormatException,
      );
      expect(
        () =>
            ReservationDto.fromJson({...reservationJson, 'totalPrice': 4500.5}),
        throwsFormatException,
      );
    });

    test('trenutak bez zone se odbija', () {
      expect(
        () => ReservationDto.fromJson({
          ...reservationJson,
          'startTime': '2026-11-20T17:00:00',
        }),
        throwsFormatException,
      );
    });

    test('zahtev za kreiranje nema userId, identitet je u tokenu', () {
      final request = CreateReservationRequestDto(
        fieldId: 3,
        startTime: DateTime.utc(2026, 11, 20, 17),
        endTime: DateTime.utc(2026, 11, 20, 18),
      );

      expect(
        request.toJson().keys,
        unorderedEquals(['fieldId', 'startTime', 'endTime']),
      );
      expect(
        CreateReservationRequestDto.fromJson(wire(request.toJson())).endTime,
        DateTime.utc(2026, 11, 20, 18),
      );
    });

    test('trenutak sa lokalnom zonom se na mreži uvek šalje u UTC', () {
      final local = DateTime.parse('2026-11-20T18:00:00+01:00');

      expect(instantToJson(local), '2026-11-20T17:00:00.000Z');
    });
  });

  group('greška', () {
    test('nosi kod i podatke pravila, ne poruku', () {
      final dto = ErrorDto.fromJson(
        wire({
          'error': {
            'code': 'cancellation_deadline_expired',
            'details': {'hours': 5},
          },
        }),
      );

      expect(dto.code, ErrorCodes.cancellationDeadlineExpired);
      expect(dto.isKnown, isTrue);
      expect(dto.detailInt(ErrorDetailKeys.hours), 5);
    });

    test('toJson daje oblik koji server šalje', () {
      const dto = ErrorDto(code: ErrorCodes.slotTaken);

      expect(dto.toJson(), {
        'error': {'code': 'slot_taken', 'details': <String, Object?>{}},
      });
    });

    test('nepoznat kod se čita bez izuzetka (stara verzija aplikacije)', () {
      final dto = ErrorDto.fromJson({
        'error': {
          'code': 'court_closed_for_holiday',
          'details': {'day': '2026-12-25'},
        },
      });

      expect(dto.code, 'court_closed_for_holiday');
      expect(dto.isKnown, isFalse);
    });

    test('telo bez polja error nije greška servera', () {
      expect(
        () => ErrorDto.fromJson({'message': 'Bad gateway'}),
        throwsFormatException,
      );
    });

    test('details koji nisu objekat se ignorišu', () {
      final dto = ErrorDto.fromJson({
        'error': {'code': 'internal', 'details': 'x'},
      });

      expect(dto.details, isEmpty);
    });
  });

  group('lista po stranama', () {
    test('čita stranu i ukupan broj', () {
      final page = PageDto.fromJson({
        'items': [
          {'sports': <String>[]},
        ],
        'total': 87,
        'limit': 20,
        'offset': 40,
      }, SportsDto.fromJson);

      expect(page.items, hasLength(1));
      expect(page.total, 87);
      expect(page.hasMore, isTrue);
      expect(
        PageDto<int>(items: [1], total: 1, limit: 20, offset: 0).hasMore,
        isFalse,
      );
    });

    test('prolazi kroz JSON i nazad', () {
      final dto = ReservationDto.fromJson(reservationJson);
      final page = PageDto(items: [dto], total: 1, limit: 20, offset: 0);

      final back = PageDto.fromJson(
        wire(page.toJson((item) => item.toJson())),
        ReservationDto.fromJson,
      );

      expect(back.items.single.id, 7);
      expect(back.total, 1);
    });
  });

  group('teren i sportovi', () {
    final fieldJson = <String, Object?>{
      'id': 3,
      'ownerId': 9,
      'name': 'Padel Arena',
      'description': 'Dva zatvorena terena',
      'sport': 'padel',
      'address': 'Dorćol 1',
      'city': 'Beograd',
      'pricePerHour': 3000,
      'contactPhone': '0641234567',
      'imageUrls': ['a.jpg'],
      'confirmationMode': 'manual',
      'isActive': true,
      'approvalStatus': 'approved',
    };

    test('prolazi kroz JSON i nazad', () {
      expect(wire(FieldDto.fromJson(fieldJson).toJson()), fieldJson);
    });

    test('nepoznat sport se čuva kakav je stigao', () {
      final dto = FieldDto.fromJson({...fieldJson, 'sport': 'curling'});

      expect(dto.sport, 'curling');
    });

    test('lista slika koja fali je prazna lista', () {
      expect(
        FieldDto.fromJson({...fieldJson}..remove('imageUrls')).imageUrls,
        isEmpty,
      );
    });

    test('zahtev za teren ne nosi vlasnika ni odobrenost', () {
      final request = SaveFieldRequestDto.fromJson(fieldJson);

      expect(request.toJson().containsKey('ownerId'), isFalse);
      expect(request.toJson().containsKey('approvalStatus'), isFalse);
    });

    test('sportovi iz GET /sports', () {
      final dto = SportsDto.fromJson({
        'sports': ['football', 'padel'],
      });

      expect(dto.sports, ['football', 'padel']);
      expect(
        () => SportsDto.fromJson({
          'sports': [1],
        }),
        throwsFormatException,
      );
    });
  });

  group('radno vreme i termini', () {
    test('radno vreme je HH:mm', () {
      final day = ScheduleDayDto.fromJson({
        'dayOfWeek': 'monday',
        'opensAt': '08:00',
        'closesAt': '22:30',
      });

      expect(day.opensAt, const ClockTime(8, 0));
      expect(day.isOpen, isTrue);
      expect(wire(day.toJson())['closesAt'], '22:30');
    });

    test('neispravno vreme se odbija', () {
      for (final bad in ['8:00', '24:00', '12:60', 'osam']) {
        expect(
          () => ScheduleDayDto.fromJson({
            'dayOfWeek': 'monday',
            'opensAt': bad,
            'closesAt': '22:00',
          }),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('dostupnost nosi stanja termina', () {
      final dto = AvailabilityDto.fromJson({
        'fieldId': 3,
        'date': '2026-11-20',
        'slots': [
          {
            'startTime': '2026-11-20T07:00:00.000Z',
            'endTime': '2026-11-20T08:00:00.000Z',
            'state': 'free',
          },
          {
            'startTime': '2026-11-20T08:00:00.000Z',
            'endTime': '2026-11-20T09:00:00.000Z',
            'state': 'taken',
          },
        ],
      });

      expect(dto.slots.map((s) => s.state), [
        SlotStateCodes.free,
        SlotStateCodes.taken,
      ]);
      expect(wire(dto.toJson())['date'], '2026-11-20');
    });

    test('datum se piše kao YYYY-MM-DD', () {
      expect(dateToJson(2026, 3, 5), '2026-03-05');
    });

    test('blokirani period prolazi kroz JSON', () {
      final dto = BlockedPeriodDto(
        fieldId: 3,
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 12),
        reason: 'Održavanje',
      );

      final back = BlockedPeriodDto.fromJson(wire(dto.toJson()));

      expect(back.reason, 'Održavanje');
      expect(back.endTime, DateTime.utc(2026, 11, 21, 12));
    });
  });

  group('prijava i nalog', () {
    final userJson = <String, Object?>{
      'id': 2,
      'firstName': 'Ana',
      'lastName': 'Jovanović',
      'email': 'ana@example.com',
      'role': 'user',
    };

    test('odgovor servera na prijavu (oblik koji server već šalje)', () {
      final session = SessionDto.fromJson({
        'token': 'abc.def.ghi',
        'expiresAt': '2026-11-17T20:00:00.000Z',
        'user': userJson,
      });

      expect(session.token, 'abc.def.ghi');
      expect(session.user.role, RoleCodes.user);
      expect(session.expiresAt.isUtc, isTrue);
    });

    test('GET /auth/me nema token', () {
      final session = SessionDto.fromJson({
        'expiresAt': '2026-11-17T20:00:00.000Z',
        'user': userJson,
      });

      expect(session.token, isNull);
    });

    test('rezervacija nosi korisnika samo kada ga server pošalje', () {
      final base = {
        'id': 1,
        'fieldId': 2,
        'userId': 4,
        'startTime': '2026-12-01T10:00:00.000Z',
        'endTime': '2026-12-01T11:00:00.000Z',
        'totalPrice': 3000,
        'status': 'pending',
        'paymentStatus': 'unpaid',
        'createdAt': '2026-11-01T00:00:00.000Z',
      };

      final without = ReservationDto.fromJson(base);
      expect(without.customer, isNull);
      expect(without.toJson().keys, isNot(contains('customer')));

      final withCustomer = ReservationDto.fromJson({...base, 'customer': userJson});
      expect(withCustomer.customer?.email, userJson['email']);
      expect(withCustomer.toJson()['customer'], isA<Map<String, Object?>>());
      expect(
        () => ReservationDto.fromJson({...base, 'customer': 'Ana'}),
        throwsFormatException,
      );
    });

    test('nalog nikad ne nosi lozinku ni heš', () {
      final json = UserDto.fromJson(userJson).toJson();

      expect(json.keys, isNot(contains('password')));
      expect(json.keys, isNot(contains('passwordHash')));
    });

    test('stanje naloga stiže samo kada ga server pošalje', () {
      final without = UserDto.fromJson(userJson);
      expect(without.isActive, isNull);
      expect(without.toJson().keys, isNot(contains('isActive')));

      final off = UserDto.fromJson({...userJson, 'isActive': false});
      expect(off.isActive, isFalse);
      expect(off.toJson()['isActive'], false);
      expect(
        () => UserDto.fromJson({...userJson, 'isActive': 'ne'}),
        throwsFormatException,
      );
    });

    test('zahtev za deaktivaciju naloga', () {
      const request = SetUserActiveRequestDto(isActive: false);

      expect(
        SetUserActiveRequestDto.fromJson(wire(request.toJson())).isActive,
        isFalse,
      );
      expect(
        () => SetUserActiveRequestDto.fromJson({}),
        throwsFormatException,
      );
      expect(ApiPaths.user(7), '/users/7');
    });

    test('deaktiviran nalog je 403, ne 401', () {
      expect(httpStatusFor(ErrorCodes.accountDeactivated), 403);
    });

    test('zahtev za prijavu', () {
      const request = LoginRequestDto(email: 'ana@example.com', password: 'x');

      expect(
        LoginRequestDto.fromJson(wire(request.toJson())).email,
        'ana@example.com',
      );
      expect(
        () => LoginRequestDto.fromJson({'email': 'a'}),
        throwsFormatException,
      );
    });
  });

  group('statistika', () {
    test('minuti i brojevi prolaze kroz JSON', () {
      final dto = OccupancyReportDto(
        period: StatsPeriodCodes.week,
        from: DateTime.utc(2026, 11, 15, 23),
        to: DateTime.utc(2026, 11, 22, 23),
        fields: const [
          FieldOccupancyDto(
            fieldId: 3,
            fieldName: 'Padel Arena',
            availableMinutes: 5040,
            bookedMinutes: 1260,
            completedCount: 6,
            cancelledCount: 1,
            activeCount: 2,
          ),
        ],
      );

      final back = OccupancyReportDto.fromJson(wire(dto.toJson()));

      expect(back.fields.single.bookedMinutes, 1260);
      expect(back.to, DateTime.utc(2026, 11, 22, 23));
    });
  });

  group('HTTP status po kodu greške', () {
    test('prati tabelu iz odluke 13', () {
      expect(httpStatusFor(ErrorCodes.slotTaken), 409);
      expect(httpStatusFor(ErrorCodes.cancellationDeadlineExpired), 422);
      expect(httpStatusFor(ErrorCodes.tokenExpired), 401);
      expect(httpStatusFor(ErrorCodes.forbidden), 403);
      expect(httpStatusFor(ErrorCodes.notFound), 404);
      expect(httpStatusFor('kod_koji_ne_postoji'), 500);
    });

    test('svaki poznat kod osim internal ima svoj status', () {
      for (final code in ErrorCodes.all.where(
        (c) => c != ErrorCodes.internal,
      )) {
        expect(httpStatusFor(code), isNot(500), reason: code);
      }
      expect(httpStatusFor(ErrorCodes.internal), 500);
    });

    test('lista svih kodova nema duplikata i svi su poznati', () {
      expect(ErrorCodes.all.toSet(), hasLength(ErrorCodes.all.length));
      for (final code in ErrorCodes.all) {
        expect(ErrorDto(code: code).isKnown, isTrue, reason: code);
      }
    });
  });

  group('adrese', () {
    test('odgovaraju odlukama 8 i 9', () {
      expect(ApiPaths.login, '/auth/login');
      expect(ApiPaths.field(3), '/fields/3');
      expect(ApiPaths.availability(3), '/fields/3/availability');
      expect(ApiPaths.cancelReservation(7), '/reservations/7/cancel');
      expect(ApiHeaders.bearer('t'), 'Bearer t');
    });
  });

  group('telo zahteva: round-trip i neispravan oblik', () {
    test('odluka o objavljivanju terena', () {
      const request = FieldReviewRequestDto(decision: 'rejected', reason: 'Nema dozvole');

      final back = FieldReviewRequestDto.fromJson(wire(request.toJson()));

      expect((back.decision, back.reason), ('rejected', 'Nema dozvole'));
      expect(
        const FieldReviewRequestDto(decision: 'approved').toJson().keys,
        isNot(contains('reason')),
      );
      expect(() => FieldReviewRequestDto.fromJson({}), throwsFormatException);
    });

    test('razlog za odbijanje ili otkazivanje rezervacije je neobavezan', () {
      expect(
        ReservationReasonRequestDto.fromJson(
          wire(const ReservationReasonRequestDto(reason: 'Turnir').toJson()),
        ).reason,
        'Turnir',
      );
      expect(ReservationReasonRequestDto.fromJson({}).reason, isNull);
      expect(const ReservationReasonRequestDto().toJson(), isEmpty);
      expect(
        () => ReservationReasonRequestDto.fromJson({'reason': 5}),
        throwsFormatException,
      );
    });

    test('zahtev za blokadu terena', () {
      final request = CreateBlockedPeriodRequestDto(
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 12),
        reason: 'Održavanje',
      );

      final back = CreateBlockedPeriodRequestDto.fromJson(wire(request.toJson()));

      expect(back.startTime, request.startTime);
      expect(back.endTime, request.endTime);
      expect(back.reason, 'Održavanje');
      expect(
        () => CreateBlockedPeriodRequestDto.fromJson({'startTime': 'sutra'}),
        throwsFormatException,
      );
    });

    test('termin i dostupnost se vraćaju iste, a trenutak bez zone se odbija', () {
      final availability = AvailabilityDto(
        fieldId: 3,
        date: '2026-11-21',
        slots: [
          SlotDto(
            startTime: DateTime.utc(2026, 11, 21, 8),
            endTime: DateTime.utc(2026, 11, 21, 9),
            state: SlotStateCodes.taken,
          ),
        ],
      );

      final back = AvailabilityDto.fromJson(wire(availability.toJson()));

      expect(back.slots.single.state, SlotStateCodes.taken);
      expect(back.slots.single.startTime, DateTime.utc(2026, 11, 21, 8));
      expect(
        () => SlotDto.fromJson({
          'startTime': '2026-11-21T08:00:00',
          'endTime': '2026-11-21T09:00:00Z',
          'state': 'free',
        }),
        throwsFormatException,
      );
    });

    test('radno vreme: sati i minuti ostaju, nevažeće vreme se odbija', () {
      final schedule = ScheduleDto(
        days: [
          const ScheduleDayDto(
            dayOfWeek: WeekDayCodes.monday,
            opensAt: ClockTime(8, 30),
            closesAt: ClockTime(22, 0),
          ),
        ],
      );

      final back = ScheduleDto.fromJson(wire(schedule.toJson()));

      expect(back.days.single.opensAt, const ClockTime(8, 30));
      expect(back.days.single.closesAt, const ClockTime(22, 0));
      expect(() => ClockTime.parse('25:00'), throwsFormatException);
      expect(() => ClockTime.parse('8:30'), throwsFormatException);
    });
  });

  group('blokade terena', () {
    test('blokada nosi identifikator koji server dodeli', () {
      final dto = BlockedPeriodDto.fromJson({
        'id': 5,
        'fieldId': 3,
        'startTime': '2026-11-21T08:00:00.000Z',
        'endTime': '2026-11-21T12:00:00.000Z',
        'reason': 'Održavanje',
      });

      expect(dto.id, 5);
      expect(wire(dto.toJson())['id'], 5);
    });

    test('blokada bez identifikatora (zahtev) ga ne šalje', () {
      final dto = BlockedPeriodDto(
        fieldId: 3,
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 12),
      );

      expect(dto.toJson().containsKey('id'), isFalse);
      expect(BlockedPeriodDto.fromJson(wire(dto.toJson())).id, isNull);
    });

    test('adresa jedne blokade i statusi grešaka blokade', () {
      expect(ApiPaths.blockedPeriod(3, 5), '/fields/3/blocked-periods/5');
      expect(httpStatusFor(ErrorCodes.blockOverlapsReservation), 409);
      expect(httpStatusFor(ErrorCodes.invalidBlockRange), 422);
      expect(httpStatusFor(ErrorCodes.blockInPast), 422);
    });
  });
}
