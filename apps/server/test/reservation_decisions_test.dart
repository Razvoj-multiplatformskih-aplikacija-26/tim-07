@Tags(['db'])
library;

import 'dart:async';

import 'package:domain/domain.dart';
import 'package:server/server.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';
import 'support/test_database.dart';

final class _BrokenGateway implements NotificationGateway {
  @override
  Future<void> send(ReservationNotification notification) async =>
      throw const NotificationFailed('service_down');
}

final class _HangingGateway implements NotificationGateway {
  @override
  Future<void> send(ReservationNotification notification) => Completer<void>().future;
}

void main() {
  TestDatabase? testDb;
  late MySqlReservationRepository reservations;
  late FakeNotificationGateway gateway;
  late List<String> errors;
  late List<String> sentLog;

  final now = DateTime(2030, 6, 3, 10);
  DateTime at(int day, int hour) => DateTime(2030, 6, day, hour);

  ReservationDecisions decisionsWith(NotificationGateway notifications) => ReservationDecisions(
        reservations: reservations,
        fields: MySqlSportsFieldRepository(testDb!.database),
        users: MySqlUserRepository(testDb!.database),
        notifications: notifications,
        notificationTimeout: const Duration(milliseconds: 200),
        logError: errors.add,
      );

  setUp(() async {
    errors = [];
    sentLog = [];
    testDb = await TestDatabase.open();
    if (testDb == null) {
      markTestSkipped(TestDatabase.skipReason!);
      return;
    }
    await testDb!.migrate();
    await insertFixtures(testDb!.database);
    reservations = MySqlReservationRepository(testDb!.database, clock: () => now);
    gateway = FakeNotificationGateway(apiKey: 'test-key', log: sentLog.add);
  });

  tearDown(() async => testDb?.dispose());

  Future<Reservation> pending() => reservations.createReservation(
        fieldId: FieldId(1), userId: UserId(1), startTime: at(4, 18), endTime: at(4, 19),
      );

  test('potvrda menja stanje i šalje obaveštenje korisniku', () async {
    if (testDb == null) return;
    final created = await pending();

    final confirmed = await decisionsWith(gateway).confirm(created.id);

    expect(confirmed.status, ReservationStatus.confirmed);
    expect(gateway.sent.single.kind, ReservationNotificationKind.confirmed);
    expect(gateway.sent.single.recipient.email, 'ana@example.com');
    expect(gateway.sent.single.field.name, 'Arena');
    expect(sentLog.single, contains('ana@example.com'));
    expect(errors, isEmpty);
  });

  test('odbijanje otkazuje rezervaciju sa razlogom i šalje obaveštenje', () async {
    if (testDb == null) return;
    final created = await pending();

    await decisionsWith(gateway).reject(created.id, reason: 'Teren je zauzet za turnir');

    final stored = await reservations.getReservationById(created.id);
    expect(stored!.status, ReservationStatus.cancelled);
    expect(stored.cancellationReason, 'Teren je zauzet za turnir');
    expect(gateway.sent.single.kind, ReservationNotificationKind.rejected);
  });

  test('potvrđena rezervacija ne može da se odbije i ništa se ne šalje', () async {
    if (testDb == null) return;
    final created = await pending();
    final decisions = decisionsWith(gateway);
    await decisions.confirm(created.id);

    await expectLater(
      decisions.reject(created.id),
      throwsA(isA<ReservationRuleViolation>()
          .having((e) => e.error, 'error', isA<InvalidReservationStatus>())),
    );
    expect(gateway.sent, hasLength(1));
    expect((await reservations.getReservationById(created.id))!.status, ReservationStatus.confirmed);
  });

  test('pad servisa ne obara potvrdu, greška se zapiše', () async {
    if (testDb == null) return;
    final created = await pending();

    final confirmed = await decisionsWith(_BrokenGateway()).confirm(created.id);

    expect(confirmed.status, ReservationStatus.confirmed);
    expect((await reservations.getReservationById(created.id))!.status, ReservationStatus.confirmed);
    expect(errors.single, contains('service_down'));
  });

  test('servis koji ne odgovara ne zadržava potvrdu duže od vremenskog ograničenja', () async {
    if (testDb == null) return;
    final created = await pending();
    final stopwatch = Stopwatch()..start();

    final confirmed = await decisionsWith(_HangingGateway()).confirm(created.id);

    expect(confirmed.status, ReservationStatus.confirmed);
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(errors.single, contains('TimeoutException'));
  });

  test('bez ključa servisa obaveštenje se ne šalje, a potvrda prolazi', () async {
    if (testDb == null) return;
    final created = await pending();
    final withoutKey = FakeNotificationGateway(apiKey: '', log: sentLog.add);

    final confirmed = await decisionsWith(withoutKey).confirm(created.id);

    expect(confirmed.status, ReservationStatus.confirmed);
    expect(withoutKey.sent, isEmpty);
    expect(errors.single, contains('missing_api_key'));
  });
}
