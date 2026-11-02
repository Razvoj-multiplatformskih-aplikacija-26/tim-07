
import 'package:domain/domain.dart';

/// Repozitorijum koji cuva rezervacije u memoriji.
///
/// Ne koristi bazu podataka ni backend.
// implements znaci da klasa mora da ima sve metode iz ugovora ReservationRepository.
final class FakeReservationRepository implements ReservationRepository {
  // "Baza" u memoriji: rezervacije, tereni, radno vreme i blokirani periodi.
  final List<Reservation> _reservations;
  final List<SportsField> _fields;
  final List<FieldSchedule> _schedules;
  final List<BlockedPeriod> _blockedPeriods;
  // Funkcija koja vraca "sada"; test moze da ubaci svoj sat umesto pravog.
  final DateTime Function() _clock;
  /// Kada je true, citanje rezervacija simulira gresku.
  bool simulateError = false;

  /// Kada je true, citanje rezervacija vraca praznu listu.
  bool simulateEmpty = false;
  // Brojac za id sledece nove rezervacije.
  int _nextReservationId;

  FakeReservationRepository({
    List<Reservation> reservations = const [],
    List<SportsField> fields = const [],
    List<FieldSchedule> schedules = const [],
    List<BlockedPeriod> blockedPeriods = const [],
    DateTime Function()? clock,
  })  : // List.of pravi izmenjivu kopiju, pa add radi i kad je prosledjen const [].
        _reservations = List.of(reservations),
        _fields = List.of(fields),
        _schedules = List.of(schedules),
        _blockedPeriods = List.of(blockedPeriods),
        // Ako sat nije prosledjen, koristi se pravi (DateTime.now je funkcija bez zagrada).
        _clock = clock ?? DateTime.now,
        // Sledeci id je najveci postojeci id + 1 (fold trazi maksimum).
        _nextReservationId = reservations.fold<int>(
          0,
              (maxId, reservation) =>
          reservation.id.value > maxId
              ? reservation.id.value
              : maxId,
        ) +
            1;

  /// Automatski osvezava statuse prema trenutnom vremenu.
  // Domen odredjuje novi status, a ovde se samo upisuje; poziva se pre svake operacije.
  void _refreshStatuses() {
    final now = _clock();

    for (var i = 0; i < _reservations.length; i++) {
      final reservation = _reservations[i];
      // Cista domenska funkcija: kaze koji status rezervacija treba da ima u trenutku now.
      final newStatus = resolveReservationStatus(reservation, now);

      if (newStatus != reservation.status) {
        // Model je nepromenljiv, zato se stara rezervacija zamenjuje novom kopijom.
        _reservations[i] = reservation.copyWith(status: newStatus);
      }
    }
  }

  // Trazi rezervaciju po id-u; ako je nema, baca gresku.
  Reservation _findReservation(ReservationId id) {
    for (final reservation in _reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }

    throw StateError('Rezervacija nije pronadjena.');
  }

  // Trazi teren po id-u; ako ga nema, baca gresku.
  SportsField _findField(FieldId id) {
    for (final field in _fields) {
      if (field.id == id) {
        return field;
      }
    }

    throw StateError('Teren nije pronadjen.');
  }


  // async umotava rezultat i bacenu gresku u Future, da se poklopi sa ugovorom.
  @override
  Future<List<Reservation>> getReservations() async {
    // Prekidac za demo greske: Bloc je hvata u catch i emituje Error.
    if (simulateError) {
      throw StateError('Simulirana greska pri ucitavanju rezervacija.');
    }

    // Prekidac za demo praznog prikaza: Bloc emituje Empty.
    if (simulateEmpty) {
      return const [];
    }

    _refreshStatuses();
    // Nepromenljiva kopija, da spoljni kod ne moze da menja internu listu.
    return List.unmodifiable(_reservations);
  }


  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async {
    _refreshStatuses();

    // where zadrzava samo rezervacije trazenog korisnika.
    return List.unmodifiable(
      _reservations.where((r) => r.userId == userId),
    );
  }

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async {
    _refreshStatuses();

    // where zadrzava samo rezervacije trazenog terena.
    return List.unmodifiable(
      _reservations.where((r) => r.fieldId == fieldId),
    );
  }

  @override
  Future<Reservation?> getReservationById(ReservationId id) async {
    _refreshStatuses();

    for (final reservation in _reservations) {
      if (reservation.id == id) {
        return reservation;
      }
    }

    // Za razliku od _findReservation, ovde nepostojeci id nije greska nego null.
    return null;
  }

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _refreshStatuses();

    final now = _clock();
    final field = _findField(fieldId);

    if (!field.isActive) {
      throw StateError('Teren trenutno nije aktivan.');
    }

    // Konacna provera termina nad svim rezervacijama (ovde repozitorijum glumi server).
    final slotError = validateReservationSlot(
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      now: now,
      existingReservations: _reservations,
      schedules: _schedules,
      blockedPeriods: _blockedPeriods,
    );

    if (slotError != null) {
      throw StateError(slotError.message);
    }

    // Cenu racuna domen, proporcionalno trajanju termina.
    final totalPrice = calculateReservationPrice(
      pricePerHour: field.pricePerHour,
      startTime: startTime,
      endTime: endTime,
    );

    // Automatsko potvrdjivanje: odmah confirmed; rucno: pending dok vlasnik ne potvrdi.
    final status = field.confirmationMode == ConfirmationMode.automatic
        ? ReservationStatus.confirmed
        : ReservationStatus.pending;

    final reservation = Reservation(
      // Koristi trenutni broj kao id, pa brojac poveca za 1.
      id: ReservationId(_nextReservationId++),
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      status: status,
      createdAt: now,
    );

    _reservations.add(reservation);

    return reservation;
  }

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async {
    _refreshStatuses();

    final reservation = _findReservation(reservationId);

    // Prvo se proverava da li je prelaz iz trenutnog u trazeni status uopste dozvoljen.
    if (!canTransitionReservationStatus(
      reservation.status,
      status,
    )) {
      throw StateError('Promena statusa nije dozvoljena.');
    }

    // Rucno potvrdjivanje mora biti pre roka od 5 sati.
    if (status == ReservationStatus.confirmed &&
        !_clock().isBefore(reservation.checkInDeadline)) {
      throw StateError('Rok za potvrdjivanje je istekao.');
    }

    // Za otkazivanje koristimo postojece domensko pravilo.
    if (status == ReservationStatus.cancelled) {
      final error = validateCancellation(
        reservation: reservation,
        now: _clock(),
      );

      if (error != null) {
        throw StateError(error.message);
      }
    }

    // Zavrsavanje rezervacije je automatsko.
    if (status == ReservationStatus.completed) {
      throw StateError(
        'Rezervacija se zavrsava automatski nakon termina.',
      );
    }

    // Pravi kopiju sa novim statusom i zamenjuje staru na istom mestu u listi.
    final updated = reservation.copyWith(status: status);
    final index = _reservations.indexWhere(
          (r) => r.id == reservationId,
    );

    _reservations[index] = updated;

    return updated;
  }

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async {
    _refreshStatuses();

    final reservation = _findReservation(reservationId);
    final now = _clock();

    // Domen proverava status, prozor za check-in i da check-in nije vec uradjen.
    final error = validateCheckIn(
      reservation: reservation,
      now: now,
    );

    if (error != null) {
      throw StateError(error.message);
    }

    // Upisuje vreme dolaska; status ostaje confirmed, a completed dolazi kasnije automatski.
    final updated = reservation.copyWith(checkedInAt: now);

    final index = _reservations.indexWhere(
          (r) => r.id == reservationId,
    );

    _reservations[index] = updated;

    return updated;
  }

  @override
  Future<Reservation> cancelReservation(
      ReservationId reservationId,
      ) async {
    // Otkazivanje je promena statusa u cancelled, pa vazi ista provera prelaza i roka.
    return updateReservationStatus(
      reservationId: reservationId,
      status: ReservationStatus.cancelled,
    );
  }
}
