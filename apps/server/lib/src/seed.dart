import 'package:domain/domain.dart';
import 'package:postgres/postgres.dart';

import 'passwords.dart';
import 'terenzo_store.dart';

const demoAccounts = [
  (email: 'korisnik1@terenzo.rs', first: 'Ana', last: 'Anić', role: UserRole.user),
  (email: 'korisnik2@terenzo.rs', first: 'Marko', last: 'Marić', role: UserRole.user),
  (email: 'korisnik3@terenzo.rs', first: 'Jelena', last: 'Jovanović', role: UserRole.user),
  (email: 'vlasnik1@terenzo.rs', first: 'Vladimir', last: 'Vlasnik', role: UserRole.owner),
  (email: 'vlasnik2@terenzo.rs', first: 'Milica', last: 'Milić', role: UserRole.owner),
  (email: 'admin@terenzo.rs', first: 'Aleksandra', last: 'Admin', role: UserRole.admin),
];

Future<void> seedDemoData(Pool<void> database, {required DateTime now, required String? demoPassword}) async {
  if (demoPassword == null || demoPassword.isEmpty) return;
  await database.runTx((tx) async {
    final store = TerenzoStore(tx);
    if (!await store.isEmpty()) return;

    final hash = await hashPassword(demoPassword);
    final ids = <String, UserId>{};
    for (final (index, account) in demoAccounts.indexed) {
      ids[account.email] = await store.insertUser(
        firstName: account.first,
        lastName: account.last,
        email: account.email,
        phoneNumber: '06${index + 1}1234567',
        dateOfBirth: DateTime(1990 + index, 1 + index, 10),
        role: account.role,
        passwordHash: hash,
      );
    }
    final ana = ids['korisnik1@terenzo.rs']!;
    final marko = ids['korisnik2@terenzo.rs']!;
    final jelena = ids['korisnik3@terenzo.rs']!;
    final vladimir = ids['vlasnik1@terenzo.rs']!;
    final milica = ids['vlasnik2@terenzo.rs']!;

    Future<SportsField> field({
      required UserId owner,
      required String name,
      required String description,
      required SportType sport,
      required String address,
      required String city,
      required int price,
      required ConfirmationMode mode,
      ApprovalStatus approval = ApprovalStatus.approved,
    }) async {
      final id = await store.insertField(
        ownerId: owner,
        name: name,
        description: description,
        sport: sport,
        address: address,
        city: city,
        pricePerHour: price,
        contactPhone: '0601234567',
        confirmationMode: mode,
        approvalStatus: approval,
      );
      await store.replaceSchedules(id, [
        for (final day in WeekDay.values)
          FieldSchedule(
            fieldId: id,
            dayOfWeek: day,
            opensAt: const TimeOfDay(hour: 8, minute: 0),
            closesAt: const TimeOfDay(hour: 23, minute: 0),
          ),
      ]);
      return (await store.field(id))!;
    }

    final arena = await field(
      owner: vladimir,
      name: 'Arena Fudbal',
      description: 'Teren za mali fudbal sa veštačkom travom.',
      sport: SportType.football,
      address: 'Bulevar kralja Aleksandra 100',
      city: 'Beograd',
      price: 3000,
      mode: ConfirmationMode.manual,
    );
    final basket = await field(
      owner: vladimir,
      name: 'Basket Park',
      description: 'Košarkaški teren za rekreaciju.',
      sport: SportType.basketball,
      address: 'Nemanjina 15',
      city: 'Beograd',
      price: 1500,
      mode: ConfirmationMode.automatic,
    );
    final tennis = await field(
      owner: milica,
      name: 'Tenis Centar',
      description: 'Otvoreni teniski teren na šljaci.',
      sport: SportType.tennis,
      address: 'Bulevar oslobođenja 50',
      city: 'Novi Sad',
      price: 2000,
      mode: ConfirmationMode.manual,
    );
    await field(
      owner: milica,
      name: 'Padel Klub',
      description: 'Dva padel terena, čeka odobrenje administratora.',
      sport: SportType.padel,
      address: 'Futoška 12',
      city: 'Novi Sad',
      price: 2800,
      mode: ConfirmationMode.manual,
      approval: ApprovalStatus.pending,
    );

    final today = DateTime(now.year, now.month, now.day);
    DateTime at(int dayOffset, int hour) => DateTime(today.year, today.month, today.day + dayOffset, hour);

    Future<void> reservation(
      SportsField field,
      UserId user,
      int dayOffset,
      int hour, {
      int hours = 1,
      required ReservationStatus status,
      bool checkedIn = false,
      String? reason,
    }) async {
      final start = at(dayOffset, hour);
      final end = start.add(Duration(hours: hours));
      await store.insertReservation(
        fieldId: field.id,
        userId: user,
        startTime: start,
        endTime: end,
        totalPrice: calculateReservationPrice(pricePerHour: field.pricePerHour, startTime: start, endTime: end),
        status: status,
        createdAt: now.subtract(const Duration(days: 10)),
        checkedInAt: checkedIn ? start.subtract(const Duration(hours: 10)) : null,
        cancellationReason: reason,
      );
    }

    await reservation(arena, ana, -6, 18, hours: 2, status: ReservationStatus.completed, checkedIn: true);
    await reservation(tennis, marko, -4, 10, status: ReservationStatus.completed, checkedIn: true);
    await reservation(basket, jelena, -2, 19, status: ReservationStatus.completed, checkedIn: true);
    await reservation(arena, marko, -3, 20, status: ReservationStatus.cancelled, reason: 'Otkazao korisnik');
    await reservation(tennis, ana, 2, 9, status: ReservationStatus.cancelled, reason: 'Teren je rezervisan za turnir');
    await reservation(arena, ana, 2, 18, status: ReservationStatus.pending);
    await reservation(arena, marko, 3, 19, hours: 2, status: ReservationStatus.pending);
    await reservation(tennis, jelena, 4, 17, status: ReservationStatus.pending);
    await reservation(basket, ana, 3, 20, status: ReservationStatus.confirmed);
    await reservation(tennis, marko, 5, 18, status: ReservationStatus.confirmed);
    await reservation(arena, jelena, 6, 21, status: ReservationStatus.confirmed);

    await store.insertBlockedPeriod(
      BlockedPeriod(fieldId: arena.id, startTime: at(7, 8), endTime: at(7, 12), reason: 'Održavanje terena'),
    );
  });
}
