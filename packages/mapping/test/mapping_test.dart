import 'dart:convert';

import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:test/test.dart';

/// Šalje JSON kroz pravi tekst i nazad, kao mreža.
Map<String, Object?> wire(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Reservation reservation({
  ReservationStatus status = ReservationStatus.pending,
  DateTime? checkedInAt,
  String? reason,
}) => Reservation(
  id: const ReservationId(7),
  fieldId: const FieldId(3),
  userId: const UserId(2),
  startTime: DateTime.utc(2026, 11, 20, 17),
  endTime: DateTime.utc(2026, 11, 20, 18, 30),
  totalPrice: 4500,
  status: status,
  paymentStatus: PaymentStatus.paid,
  checkedInAt: checkedInAt,
  cancellationReason: reason,
  createdAt: DateTime.utc(2026, 11, 17, 9, 15),
);

SportsField field({
  SportType sport = SportType.padel,
  ApprovalStatus approval = ApprovalStatus.approved,
  String? rejection,
}) => SportsField(
  id: const FieldId(3),
  ownerId: const UserId(9),
  name: 'Padel Arena',
  description: 'Dva zatvorena terena',
  sport: sport,
  address: 'Dorćol 1',
  city: 'Beograd',
  pricePerHour: 3000,
  contactPhone: '0641234567',
  imageUrls: const ['a.jpg', 'b.jpg'],
  confirmationMode: ConfirmationMode.manual,
  isActive: true,
  approvalStatus: approval,
  rejectionReason: rejection,
);

void main() {
  group('kodovi', () {
    test('svaka vrednost enuma ima kod i vraća se ista', () {
      for (final v in ReservationStatus.values) {
        expect(reservationStatusFromCode(reservationStatusToCode(v)), v);
      }
      for (final v in PaymentStatus.values) {
        expect(paymentStatusFromCode(paymentStatusToCode(v)), v);
      }
      for (final v in UserRole.values) {
        expect(roleFromCode(roleToCode(v)), v);
      }
      for (final v in SportType.values) {
        expect(sportFromCode(sportToCode(v)), v);
      }
      for (final v in ConfirmationMode.values) {
        expect(confirmationModeFromCode(confirmationModeToCode(v)), v);
      }
      for (final v in ApprovalStatus.values) {
        expect(approvalStatusFromCode(approvalStatusToCode(v)), v);
      }
      for (final v in WeekDay.values) {
        expect(weekDayFromCode(weekDayToCode(v)), v);
      }
      for (final v in StatsPeriodKind.values) {
        expect(statsPeriodFromCode(statsPeriodToCode(v)), v);
      }
    });

    test('kodovi su stabilni tekstovi iz ugovora, ne indeksi', () {
      expect(reservationStatusToCode(ReservationStatus.cancelled), 'cancelled');
      expect(sportToCode(SportType.football), 'football');
      expect(roleToCode(UserRole.owner), 'owner');
    });

    test('kolone sortiranja imaju stabilne kodove i vraćaju se iste', () {
      for (final v in ReservationSortKey.values) {
        expect(reservationSortKeyFromCode(reservationSortKeyToCode(v)), v);
      }
      expect(reservationSortKeyToCode(ReservationSortKey.startTime), 'start');
      expect(reservationSortKeyFromCode('price'), isNull);
    });

    test('nepoznat kod daje null, a requireKnown baca izuzetak', () {
      expect(reservationStatusFromCode('no_show'), isNull);
      expect(sportFromCode('curling'), isNull);
      expect(
        () => requireKnown(sportFromCode('curling'), 'sport', 'curling'),
        throwsA(
          isA<UnknownCodeException>()
              .having((e) => e.kind, 'kind', 'sport')
              .having((e) => e.code, 'code', 'curling'),
        ),
      );
    });
  });

  group('rezervacija', () {
    test('prolazi kroz ugovor i JSON za svako stanje', () {
      for (final status in ReservationStatus.values) {
        final original = reservation(
          status: status,
          checkedInAt: status == ReservationStatus.completed
              ? DateTime.utc(2026, 11, 19, 10)
              : null,
          reason: status == ReservationStatus.cancelled
              ? 'Promena plana'
              : null,
        );

        final back = ReservationDto.fromJson(wire(original.toDto().toJson()))
            .toDomain();

        expect(back.id, original.id);
        expect(back.fieldId, original.fieldId);
        expect(back.userId, original.userId);
        // Isti trenutak, ali u lokalnom vremenu klijenta, ne u UTC.
        expect(back.startTime.isAtSameMomentAs(original.startTime), isTrue);
        expect(back.endTime.isAtSameMomentAs(original.endTime), isTrue);
        expect(back.startTime.isUtc, isFalse);
        expect(back.totalPrice, original.totalPrice);
        expect(back.status, status);
        expect(back.paymentStatus, PaymentStatus.paid);
        if (original.checkedInAt case final checkedIn?) {
          expect(back.checkedInAt!.isAtSameMomentAs(checkedIn), isTrue);
        } else {
          expect(back.checkedInAt, isNull);
        }
        expect(back.cancellationReason, original.cancellationReason);
        expect(back.createdAt.isAtSameMomentAs(original.createdAt), isTrue);
      }
    });

    test('nepoznato stanje: toDomain baca, toDomainOrNull daje null', () {
      final dto = ReservationDto.fromJson({
        ...wire(reservation().toDto().toJson()),
        'status': 'no_show',
      });

      expect(dto.toDomain, throwsA(isA<UnknownCodeException>()));
      expect(dto.toDomainOrNull(), isNull);
    });

    test('lista preskače rezervaciju sa nepoznatim kodom, ostale zadržava', () {
      final good = reservation().toDto();
      final unknown = ReservationDto.fromJson({
        ...good.toJson(),
        'id': 8,
        'status': 'no_show',
      });

      final domain = [good, unknown, good].toDomainKnown();

      expect(domain, hasLength(2));
    });

    test('zahtev za kreiranje daje teren i termin, ne korisnika', () {
      final request = CreateReservationRequestDto(
        fieldId: 3,
        startTime: DateTime.utc(2026, 11, 20, 17),
        endTime: DateTime.utc(2026, 11, 20, 18),
      );

      final parsed = request.toDomain();

      expect(parsed.fieldId, const FieldId(3));
      expect(parsed.endTime, DateTime.utc(2026, 11, 20, 18));
    });
  });

  group('teren', () {
    test('prolazi kroz ugovor i JSON', () {
      final original = field(
        approval: ApprovalStatus.rejected,
        rejection: 'Nedostaju slike',
      );

      final back = FieldDto.fromJson(wire(original.toDto().toJson()))
          .toDomain();

      expect(back.id, original.id);
      expect(back.ownerId, original.ownerId);
      expect(back.sport, SportType.padel);
      expect(back.pricePerHour, 3000);
      expect(back.imageUrls, ['a.jpg', 'b.jpg']);
      expect(back.confirmationMode, ConfirmationMode.manual);
      expect(back.approvalStatus, ApprovalStatus.rejected);
      expect(back.rejectionReason, 'Nedostaju slike');
    });

    test('nepoznat sport: teren se preskače u listi, ne obara je', () {
      final unknown = FieldDto.fromJson({
        ...field().toDto().toJson(),
        'id': 4,
        'sport': 'curling',
      });

      final domain = [field().toDto(), unknown].toDomainKnown();

      expect(domain.map((f) => f.id), [const FieldId(3)]);
      expect(unknown.toDomain, throwsA(isA<UnknownCodeException>()));
    });

    test('izmena ne menja vlasnika ni odobrenost', () {
      final existing = field(approval: ApprovalStatus.approved);
      final request = SaveFieldRequestDto.fromJson(
        wire({
          ...existing.toSaveRequest().toJson(),
          'name': 'Novi naziv',
          'pricePerHour': 3500,
          'sport': 'tennis',
        }),
      );

      final updated = request.applyTo(existing);

      expect(updated.name, 'Novi naziv');
      expect(updated.pricePerHour, 3500);
      expect(updated.sport, SportType.tennis);
      expect(updated.ownerId, existing.ownerId);
      expect(updated.id, existing.id);
      expect(updated.approvalStatus, ApprovalStatus.approved);
    });

    test('zahtev za izmenu sa nepoznatim sportom baca izuzetak', () {
      final request = SaveFieldRequestDto.fromJson({
        ...field().toSaveRequest().toJson(),
        'sport': 'curling',
      });

      expect(request.toSport, throwsA(isA<UnknownCodeException>()));
    });

    test('sportovi iz GET /sports: poznati ostaju, nepoznati se preskaču', () {
      final dto = SportsDto.fromJson({
        'sports': ['football', 'curling', 'padel'],
      });

      expect(dto.toDomainKnown(), [SportType.football, SportType.padel]);
      expect([SportType.tennis, SportType.futsal].toDto().sports, [
        'tennis',
        'futsal',
      ]);
    });
  });

  group('radno vreme i blokade', () {
    test('radno vreme prolazi kroz ugovor i JSON', () {
      final schedule = [
        const FieldSchedule(
          fieldId: FieldId(3),
          dayOfWeek: WeekDay.monday,
          opensAt: TimeOfDay(hour: 8, minute: 0),
          closesAt: TimeOfDay(hour: 22, minute: 30),
        ),
        const FieldSchedule(
          fieldId: FieldId(3),
          dayOfWeek: WeekDay.sunday,
          opensAt: TimeOfDay(hour: 9, minute: 0),
          closesAt: TimeOfDay(hour: 14, minute: 0),
          isOpen: false,
        ),
      ];

      final back = ScheduleDto.fromJson(wire(schedule.toDto().toJson()))
          .toDomain(const FieldId(3));

      expect(back, hasLength(2));
      expect(back[0].dayOfWeek, WeekDay.monday);
      expect(back[0].closesAt.hour, 22);
      expect(back[0].closesAt.minute, 30);
      expect(back[1].isOpen, isFalse);
      expect(back.every((day) => day.fieldId == const FieldId(3)), isTrue);
    });

    test('nepoznat dan u nedelji baca izuzetak', () {
      final dto = ScheduleDayDto.fromJson({
        'dayOfWeek': 'someday',
        'opensAt': '08:00',
        'closesAt': '10:00',
      });

      expect(
        () => dto.toDomain(const FieldId(3)),
        throwsA(isA<UnknownCodeException>()),
      );
    });

    test('blokirani period prolazi kroz ugovor i JSON', () {
      final period = BlockedPeriod(
        fieldId: const FieldId(3),
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 12),
        reason: 'Održavanje',
      );

      final back = BlockedPeriodDto.fromJson(wire(period.toDto().toJson()))
          .toDomain();

      expect(back.fieldId, const FieldId(3));
      expect(back.reason, 'Održavanje');
      expect(back.endTime.isAtSameMomentAs(DateTime.utc(2026, 11, 21, 12)), isTrue);
      expect(back.endTime.isUtc, isFalse);
    });

    test('blokada i rezervacija sa servera se prikazuju u lokalnom vremenu', () {
      // 07:00Z je 08:00 po beogradskom vremenu zimi, a na računaru sa tom zonom
      // ekran mora da pokaže 08:00, ne 07:00.
      final block = BlockedPeriodDto.fromJson({
        'fieldId': 3,
        'startTime': '2026-11-26T07:00:00.000Z',
        'endTime': '2026-11-26T11:00:00.000Z',
      }).toDomain();

      expect(block.startTime, DateTime.utc(2026, 11, 26, 7).toLocal());
      expect(block.startTime.hour, DateTime.utc(2026, 11, 26, 7).toLocal().hour);
      expect(block.startTime.isUtc, isFalse);
    });

    test('zahtev za blokadu dobija teren iz adrese', () {
      final request = CreateBlockedPeriodRequestDto(
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 9),
      );

      expect(request.toDomain(const FieldId(5)).fieldId, const FieldId(5));
    });
  });

  group('korisnik', () {
    final user = AppUser(
      id: const UserId(2),
      firstName: 'Ana',
      lastName: 'Jovanović',
      email: 'ana@example.com',
      phoneNumber: '0642222222',
      dateOfBirth: DateTime(2001, 7, 19),
      role: UserRole.owner,
      createdAt: DateTime.utc(2025, 3, 10),
    );

    test(
      'podrazumevano se ne šalju telefon, datum registracije ni rođenja',
      () {
        final json = user.toDto().toJson();

        expect(json.keys, isNot(contains('phoneNumber')));
        expect(json.keys, isNot(contains('createdAt')));
        expect(json.keys, isNot(contains('dateOfBirth')));
        expect(json['role'], 'owner');
      },
    );

    test('administrator dobija kontakt podatke, ali ne datum rođenja', () {
      final json = user.toDto(includeContact: true).toJson();

      expect(json['phoneNumber'], '0642222222');
      expect(json['createdAt'], '2025-03-10T00:00:00.000Z');
      expect(json.keys, isNot(contains('dateOfBirth')));
    });

    test('rezervacija sa korisnikom ga nosi sa kontaktom, ali bez datuma rođenja', () {
      final reservation = Reservation(
        id: const ReservationId(1),
        fieldId: const FieldId(2),
        userId: user.id,
        startTime: DateTime.utc(2026, 12, 1, 10),
        endTime: DateTime.utc(2026, 12, 1, 11),
        totalPrice: 3000,
        status: ReservationStatus.pending,
        createdAt: DateTime.utc(2026, 11, 1),
        customer: user,
      );

      final json = reservation.toDto().toJson();
      final customer = json['customer']! as Map<String, Object?>;
      expect(customer['phoneNumber'], '0642222222');
      expect(customer.keys, isNot(contains('dateOfBirth')));

      final back = ReservationDto.fromJson(wire(json)).toDomain();
      expect(back.customer?.fullName, 'Ana Jovanović');
      expect(back.userId, user.id);
      expect(
        ReservationDto.fromJson(wire(reservation.withCustomer(null).toDto().toJson())).toDomain().customer,
        isNull,
      );
    });

    test('stanje naloga ide samo administratoru, a bez njega je nalog aktivan', () {
      final off = user.copyWith(isActive: false);

      expect(off.toDto().toJson().keys, isNot(contains('isActive')));
      expect(off.toDto(includeContact: true).toJson()['isActive'], false);

      final back = UserDto.fromJson(
        wire(off.toDto(includeContact: true).toJson()),
      ).toDomain();
      expect(back.isActive, isFalse);
      expect(UserDto.fromJson(wire(off.toDto().toJson())).toDomain().isActive, isTrue);
    });

    test('prijavljen korisnik se vraća sa istim identitetom i ulogom', () {
      final back = UserDto.fromJson(wire(user.toDto().toJson())).toDomain();

      expect(back.id, user.id);
      expect(back.fullName, 'Ana Jovanović');
      expect(back.role, UserRole.owner);
      expect(back.email, 'ana@example.com');
    });

    test('nepoznata uloga baca izuzetak', () {
      final dto = UserDto.fromJson({
        ...user.toDto().toJson(),
        'role': 'superuser',
      });

      expect(dto.toDomain, throwsA(isA<UnknownCodeException>()));
    });
  });

  group('statistika', () {
    test('granice perioda se čuvaju tačno kako ih je server poslao', () {
      // Ponedeljak 00:00 po beogradskom vremenu je nedelja 23:00 UTC.
      final from = DateTime.utc(2026, 11, 15, 23);
      final to = DateTime.utc(2026, 11, 22, 23);
      final dto = OccupancyReportDto(
        period: StatsPeriodCodes.week,
        from: from,
        to: to,
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

      final report = OccupancyReportDto.fromJson(wire(dto.toJson())).toDomain();

      expect(report.period.kind, StatsPeriodKind.week);
      expect(report.period.from, from);
      expect(report.period.to, to);
      expect(report.fields.single.occupancyPercent, 25);
      expect(report.completedCount, 6);
    });

    test('domen -> ugovor -> domen čuva brojeve', () {
      final report = OccupancyReport(
        period: StatsPeriod.exact(
          StatsPeriodKind.month,
          DateTime.utc(2026, 10, 31, 23),
          DateTime.utc(2026, 11, 30, 23),
        ),
        fields: const [
          FieldOccupancy(
            fieldId: FieldId(3),
            fieldName: 'Padel Arena',
            availableMinutes: 100,
            bookedMinutes: 50,
            completedCount: 3,
            cancelledCount: 2,
            activeCount: 1,
          ),
        ],
      );

      final back = OccupancyReportDto.fromJson(wire(report.toDto().toJson()))
          .toDomain();

      expect(back.period.kind, StatsPeriodKind.month);
      expect(back.bookedMinutes, 50);
      expect(back.cancelledCount, 2);
      expect(back.fields.single.fieldName, 'Padel Arena');
    });

    test('nepoznat period baca izuzetak', () {
      final dto = OccupancyReportDto(
        period: 'year',
        from: DateTime.utc(2026),
        to: DateTime.utc(2027),
        fields: const [],
      );

      expect(dto.toDomain, throwsA(isA<UnknownCodeException>()));
    });
  });

  group('greške pravila', () {
    const errors = <ReservationValidationError>[
      InvalidTimeRange(),
      ReservationInPast(),
      CheckInNotAllowed(),
      CancellationDeadlineExpired(),
      InvalidReservationStatus(),
      InvalidReservationDuration(),
      OutsideWorkingHours(),
      FieldBlocked(),
      SlotAlreadyTaken(),
      FieldUnavailable(),
    ];

    test('svako pravilo ima kod i vraća se kao isto pravilo', () {
      for (final error in errors) {
        final dto = ErrorDto.fromJson(wire(error.toErrorDto().toJson()));

        expect(dto.isKnown, isTrue, reason: dto.code);
        expect(
          dto.toValidationError().runtimeType,
          error.runtimeType,
          reason: dto.code,
        );
      }
    });

    test('svaki kod pravila je različit', () {
      final codes = {for (final error in errors) error.toErrorDto().code};

      expect(codes, hasLength(errors.length));
    });

    test('preklapanje je 409, a ostala pravila 422', () {
      expect(const SlotAlreadyTaken().toFailure().status, 409);
      expect(const InvalidReservationStatus().toFailure().status, 409);
      expect(const ReservationInPast().toFailure().status, 422);
      expect(const OutsideWorkingHours().toFailure().status, 422);
    });

    test('rok otkazivanja nosi broj sati iz domena', () {
      final dto = const CancellationDeadlineExpired().toErrorDto();

      expect(dto.detailInt(ErrorDetailKeys.hours), 5);
      expect(
        dto.detailInt(ErrorDetailKeys.hours),
        Reservation.checkInClosesHoursBefore,
      );
    });

    test('rok iz greške se poklapa sa pravilom koje je server primenio', () {
      final start = DateTime.utc(2026, 11, 20, 17);
      final r = reservation().copyWith();
      final hours = const CancellationDeadlineExpired().toErrorDto().detailInt(
        ErrorDetailKeys.hours,
      )!;

      expect(r.startTime.difference(r.checkInDeadline).inHours, hours);
      expect(start.subtract(Duration(hours: hours)), r.checkInDeadline);
    });

    test('check-in nosi oba prozora', () {
      final dto = const CheckInNotAllowed().toErrorDto();

      expect(dto.detailInt(ErrorDetailKeys.opensHours), 24);
      expect(dto.detailInt(ErrorDetailKeys.closesHours), 5);
    });

    test('sukob radnog vremena i rezervacija nosi broj i najraniju rezervaciju', () {
      final conflict = ScheduleConflictsWithReservations(
        count: 3,
        firstStart: DateTime(2026, 11, 20, 15),
      );

      final dto = conflict.toErrorDto();

      expect(dto.code, ErrorCodes.scheduleConflictsWithReservations);
      expect(dto.detailInt(ErrorDetailKeys.count), 3);
      expect(dto.details[ErrorDetailKeys.date], '2026-11-20');
      expect(dto.details[ErrorDetailKeys.time], '15:00');
      expect(failureOf(ScheduleRuleViolation(conflict))?.error.code, ErrorCodes.scheduleConflictsWithReservations);
    });

    test('ostale greške radnog vremena i dalje nisu greška za mrežu', () {
      expect(failureOf(const ScheduleRuleViolation(OpeningAfterClosing(WeekDay.monday))), isNull);
    });

    test('nepoznat kod nije pravilo (stara verzija aplikacije)', () {
      const dto = ErrorDto(code: 'court_closed_for_holiday');

      expect(dto.isKnown, isFalse);
      expect(dto.toValidationError(), isNull);
    });

    test('kodovi koji nisu pravila se ne pretvaraju u pravilo', () {
      for (final code in [
        ErrorCodes.forbidden,
        ErrorCodes.tokenExpired,
        ErrorCodes.notFound,
        ErrorCodes.internal,
      ]) {
        expect(ErrorDto(code: code).toValidationError(), isNull, reason: code);
      }
    });
  });

  group('izuzeci domena u greške za mrežu', () {
    test('povreda pravila postaje kod tog pravila', () {
      final failure = failureOf(
        const ReservationRuleViolation(SlotAlreadyTaken()),
      );

      expect(failure!.error.code, ErrorCodes.slotTaken);
      expect(failure.status, 409);
    });

    test('nepostojeći zapis je not_found bez podataka o zapisu', () {
      final failure = failureOf(const EntityNotFound('Reservation', 7));

      expect(failure!.status, 404);
      expect(failure.error.details, isEmpty);
    });

    test('nedozvoljen prelaz odobrenosti nosi staro i novo stanje', () {
      final failure = failureOf(
        const ApprovalTransitionNotAllowed(
          ApprovalStatus.approved,
          ApprovalStatus.pending,
        ),
      );

      expect(failure!.status, 409);
      expect(failure.error.code, ErrorCodes.invalidApprovalTransition);
      expect(failure.error.details[ErrorDetailKeys.from], 'approved');
      expect(failure.error.details[ErrorDetailKeys.to], 'pending');
    });

    test('nepoznat izuzetak nije greška domena', () {
      expect(failureOf(StateError('baza je pala')), isNull);
    });
  });

  group('termini terena', () {
    test('stanje termina ima kod i vraća se isto', () {
      for (final state in SlotState.values) {
        expect(slotStateFromCode(slotStateToCode(state)), state);
      }
      expect(slotStateToCode(SlotState.taken), 'taken');
      expect(slotStateFromCode('maintenance'), isNull);
    });

    test('dan terena prolazi kroz ugovor i JSON', () {
      final slots = [
        AvailabilitySlot(
          startTime: DateTime.utc(2026, 11, 20, 8),
          endTime: DateTime.utc(2026, 11, 20, 9),
          state: SlotState.free,
        ),
        AvailabilitySlot(
          startTime: DateTime.utc(2026, 11, 20, 9),
          endTime: DateTime.utc(2026, 11, 20, 10),
          state: SlotState.blocked,
        ),
      ];

      final dto = slots.toDto(
        fieldId: const FieldId(3),
        date: DateTime(2026, 11, 20),
      );
      final back = AvailabilityDto.fromJson(wire(dto.toJson())).toDomain();

      expect(dto.date, '2026-11-20');
      expect(dto.fieldId, 3);
      expect(back.map((s) => s.state), [SlotState.free, SlotState.blocked]);
      expect(back.first.startTime, DateTime.utc(2026, 11, 20, 8));
      expect(back.first.duration, const Duration(hours: 1));
    });

    test('lokalni termini idu na mrežu u UTC', () {
      final slot = AvailabilitySlot(
        startTime: DateTime(2026, 11, 20, 8),
        endTime: DateTime(2026, 11, 20, 9),
        state: SlotState.free,
      );

      expect(slot.toDto().startTime.isUtc, isTrue);
      expect(slot.toDto().startTime, DateTime(2026, 11, 20, 8).toUtc());
    });

    test('dan bez termina (teren ne radi) ostaje prazna lista', () {
      final dto = <AvailabilitySlot>[].toDto(
        fieldId: const FieldId(3),
        date: DateTime(2026, 11, 22),
      );

      expect(AvailabilityDto.fromJson(wire(dto.toJson())).toDomain(), isEmpty);
    });

    test(
      'nepoznato stanje termina baca izuzetak, ne pretvara se u slobodan',
      () {
        final dto = SlotDto(
          startTime: DateTime.utc(2026, 11, 20, 8),
          endTime: DateTime.utc(2026, 11, 20, 9),
          state: 'maintenance',
        );

        expect(dto.toDomain, throwsA(isA<UnknownCodeException>()));
      },
    );
  });

  group('blokade terena', () {
    final block = BlockedPeriod(
      id: const BlockedPeriodId(5),
      fieldId: const FieldId(3),
      startTime: DateTime.utc(2026, 11, 21, 8),
      endTime: DateTime.utc(2026, 11, 21, 12),
      reason: 'Održavanje',
    );

    test('blokada sa identifikatorom prolazi kroz ugovor i JSON', () {
      final back = BlockedPeriodDto.fromJson(wire(block.toDto().toJson()))
          .toDomain();

      expect(back.id, const BlockedPeriodId(5));
      expect(back.fieldId, const FieldId(3));
      expect(back.reason, 'Održavanje');
    });

    test('blokada bez identifikatora ostaje bez njega', () {
      final draft = BlockedPeriod(
        fieldId: const FieldId(3),
        startTime: DateTime.utc(2026, 11, 21, 8),
        endTime: DateTime.utc(2026, 11, 21, 12),
      );

      expect(
        BlockedPeriodDto.fromJson(wire(draft.toDto().toJson())).toDomain().id,
        isNull,
      );
    });

    test('svako pravilo blokade ima kod i vraća se kao isto pravilo', () {
      const errors = <BlockedPeriodError>[
        InvalidBlockRange(),
        BlockInPast(),
        BlockOverlapsConfirmedReservation(),
      ];

      for (final error in errors) {
        final dto = ErrorDto.fromJson(wire(error.toErrorDto().toJson()));

        expect(dto.isKnown, isTrue, reason: dto.code);
        expect(dto.toBlockedPeriodError().runtimeType, error.runtimeType);
        // Isti kod nije pravilo rezervacije.
        expect(dto.toValidationError(), isNull);
      }
      expect({
        for (final e in errors) e.toErrorDto().code,
      }, hasLength(errors.length));
    });

    test('preklapanje sa rezervacijom je 409, ostalo 422', () {
      expect(const BlockOverlapsConfirmedReservation().toFailure().status, 409);
      expect(const InvalidBlockRange().toFailure().status, 422);
      expect(const BlockInPast().toFailure().status, 422);
    });

    test('izuzetak repozitorijuma postaje greška za mrežu', () {
      final failure = failureOf(
        const BlockedPeriodRuleViolation(BlockOverlapsConfirmedReservation()),
      );

      expect(failure!.error.code, ErrorCodes.blockOverlapsReservation);
      expect(failure.status, 409);
    });

    test('kod rezervacije nije pravilo blokade', () {
      expect(
        const ErrorDto(code: ErrorCodes.slotTaken).toBlockedPeriodError(),
        isNull,
      );
      expect(const ErrorDto(code: 'nepoznat').toBlockedPeriodError(), isNull);
    });
  });
}
