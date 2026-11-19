import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

// --- događaji -------------------------------------------------------------

sealed class ReservationFormEvent extends Equatable {
  const ReservationFormEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj ono što je potrebno za proveru termina (radno vreme, blokade i
/// korisnikove rezervacije). Šalje se na početku i za „Pokušaj ponovo“.
final class ReservationFormStarted extends ReservationFormEvent {
  const ReservationFormStarted();
}

final class ReservationFormStartChanged extends ReservationFormEvent {
  final String text;

  const ReservationFormStartChanged(this.text);

  @override
  List<Object?> get props => [text];
}

final class ReservationFormEndChanged extends ReservationFormEvent {
  final String text;

  const ReservationFormEndChanged(this.text);

  @override
  List<Object?> get props => [text];
}

final class ReservationFormSubmitted extends ReservationFormEvent {
  const ReservationFormSubmitted();
}

// --- stanja ---------------------------------------------------------------

/// Forma za rezervaciju. Svako stanje nosi unos, pa ga slanje, odbijanje ni
/// greška ne brišu (isto kao u primeru Rafstoran).
sealed class ReservationFormState extends Equatable {
  /// Šta je korisnik uneo, kako je uneo (HH:mm).
  final String startText;
  final String endText;

  const ReservationFormState({required this.startText, required this.endText});

  @override
  List<Object?> get props => [startText, endText];
}

/// Učitava se radno vreme, blokade i korisnikove rezervacije.
final class ReservationFormLoading extends ReservationFormState {
  const ReservationFormLoading({
    required super.startText,
    required super.endText,
  });
}

/// Provera nije mogla da se pripremi (nema mreže); „Pokušaj ponovo“.
final class ReservationFormLoadFailed extends ReservationFormState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const ReservationFormLoadFailed(
    this.message, {
    required super.startText,
    required super.endText,
  });

  @override
  List<Object?> get props => [...super.props, message];
}

/// Korisnik unosi termin. Provera pravila je uživo, istim funkcijama iz domena
/// koje koristi i server; server ipak odlučuje konačno.
final class ReservationFormEditing extends ReservationFormState {
  /// Vreme nije u obliku HH:mm.
  final bool startInvalid;
  final bool endInvalid;

  /// Prvo prekršeno pravilo za izabrani termin, ili `null`. Poruku pravi ekran
  /// iz tipa (`validationMessage`), pa je ista kao kada pravilo odbije server.
  final ReservationValidationError? slotError;

  /// Cena u dinarima kada je termin ispravno unet.
  final int? price;

  const ReservationFormEditing({
    required super.startText,
    required super.endText,
    this.startInvalid = false,
    this.endInvalid = false,
    this.slotError,
    this.price,
  });

  /// Termin je ispravan i može da se pošalje.
  bool get canSubmit =>
      !startInvalid && !endInvalid && slotError == null && price != null;

  @override
  List<Object?> get props => [
    ...super.props,
    startInvalid,
    endInvalid,
    slotError,
    price,
  ];
}

final class ReservationFormSubmitting extends ReservationFormState {
  const ReservationFormSubmitting({
    required super.startText,
    required super.endText,
  });
}

final class ReservationFormSucceeded extends ReservationFormState {
  final Reservation reservation;

  const ReservationFormSucceeded(
    this.reservation, {
    required super.startText,
    required super.endText,
  });

  @override
  List<Object?> get props => [...super.props, reservation.id];
}

/// Server je odbio rezervaciju (npr. termin je u međuvremenu zauzet). Podaci za
/// proveru su ponovo učitani, a unos ostaje, pa korisnik može da izabere drugi termin.
final class ReservationFormRejected extends ReservationFormState {
  /// Poruka za korisnika, ista kao kada isto pravilo proveri klijent.
  final String message;

  const ReservationFormRejected(
    this.message, {
    required super.startText,
    required super.endText,
  });

  @override
  List<Object?> get props => [...super.props, message];
}

/// Slanje nije uspelo zbog mreže ili servera; unos ostaje, može da se pošalje ponovo.
final class ReservationFormFailed extends ReservationFormState {
  final String message;

  const ReservationFormFailed(
    this.message, {
    required super.startText,
    required super.endText,
  });

  @override
  List<Object?> get props => [...super.props, message];
}

// --- Bloc -----------------------------------------------------------------

/// Vreme `HH:mm` na izabranom danu, ili `null` kada tekst nije vreme.
DateTime? parseTimeOnDate(DateTime date, String text) {
  final match = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(text);
  if (match == null) return null;

  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;

  return DateTime(date.year, date.month, date.day, hour, minute);
}

/// Forma za novu rezervaciju terena: provera termina, slanje i ishod.
///
/// Ne zna da li je iza repozitorijuma server ili memorija. Slanje i provera ne
/// žive u ekranu: ekran šalje događaje i crta stanje.
final class ReservationFormBloc
    extends Bloc<ReservationFormEvent, ReservationFormState> {
  final ReservationRepository reservations;
  final FieldScheduleRepository schedules;
  final SportsField field;
  final UserId userId;

  /// Dan rezervacije (koriste se godina, mesec i dan).
  final DateTime date;
  final DateTime Function() _clock;

  // Ono što je potrebno za lokalnu proveru. Server ipak odlučuje konačno.
  var _context = const _CheckData();
  var _loads = 0;

  ReservationFormBloc({
    required this.reservations,
    required this.schedules,
    required this.field,
    required this.userId,
    required this.date,
    required String initialStart,
    required String initialEnd,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(
         ReservationFormLoading(startText: initialStart, endText: initialEnd),
       ) {
    on<ReservationFormStarted>(_onStarted);
    on<ReservationFormStartChanged>(
      (event, emit) => _edit(emit, start: event.text),
    );
    on<ReservationFormEndChanged>(
      (event, emit) => _edit(emit, end: event.text),
    );
    on<ReservationFormSubmitted>(_onSubmitted);
  }

  Future<void> _onStarted(
    ReservationFormStarted event,
    Emitter<ReservationFormState> emit,
  ) async {
    final current = state;
    emit(
      ReservationFormLoading(
        startText: current.startText,
        endText: current.endText,
      ),
    );

    final load = ++_loads;
    try {
      final data = await _loadCheckData();
      if (load != _loads) return;

      _context = data;
      emit(_check(current.startText, current.endText));
    } catch (error) {
      if (load != _loads) return;
      emit(
        ReservationFormLoadFailed(
          describeError(error),
          startText: current.startText,
          endText: current.endText,
        ),
      );
    }
  }

  Future<_CheckData> _loadCheckData() async {
    final results = await Future.wait([
      schedules.getSchedules(field.id),
      schedules.getBlockedPeriods(field.id),
      reservations.getReservationsByUser(userId),
    ]);

    return _CheckData(
      schedules: results[0] as List<FieldSchedule>,
      blockedPeriods: results[1] as List<BlockedPeriod>,
      ownReservations: results[2] as List<Reservation>,
    );
  }

  void _edit(Emitter<ReservationFormState> emit, {String? start, String? end}) {
    final current = state;

    // Dok se podaci učitavaju, ili posle uspeha, unos se ne menja.
    if (current is ReservationFormLoading ||
        current is ReservationFormLoadFailed ||
        current is ReservationFormSubmitting ||
        current is ReservationFormSucceeded) {
      return;
    }

    emit(_check(start ?? current.startText, end ?? current.endText));
  }

  /// Stanje unosa sa proverom pravila nad onim što je učitano.
  ReservationFormEditing _check(String startText, String endText) {
    final start = parseTimeOnDate(date, startText);
    final end = parseTimeOnDate(date, endText);

    if (start == null || end == null) {
      return ReservationFormEditing(
        startText: startText,
        endText: endText,
        startInvalid: start == null,
        endInvalid: end == null,
      );
    }

    final error = validateReservationSlot(
      fieldId: field.id,
      userId: userId,
      startTime: start,
      endTime: end,
      now: _clock(),
      existingReservations: _context.ownReservations,
      schedules: _context.schedules,
      blockedPeriods: _context.blockedPeriods,
    );

    return ReservationFormEditing(
      startText: startText,
      endText: endText,
      slotError: error,
      price: end.isAfter(start)
          ? calculateReservationPrice(
              pricePerHour: field.pricePerHour,
              startTime: start,
              endTime: end,
            )
          : null,
    );
  }

  Future<void> _onSubmitted(
    ReservationFormSubmitted event,
    Emitter<ReservationFormState> emit,
  ) async {
    final current = state;

    // Šalje se samo iz unosa; dvostruki klik i slanje pre učitavanja se ignorišu.
    if (current is ReservationFormLoading ||
        current is ReservationFormLoadFailed ||
        current is ReservationFormSubmitting ||
        current is ReservationFormSucceeded) {
      return;
    }

    final checked = _check(current.startText, current.endText);
    if (!checked.canSubmit) {
      // Prikaži šta ne valja umesto da se pošalje.
      emit(checked);
      return;
    }

    final start = parseTimeOnDate(date, current.startText)!;
    final end = parseTimeOnDate(date, current.endText)!;

    emit(
      ReservationFormSubmitting(
        startText: current.startText,
        endText: current.endText,
      ),
    );

    try {
      final created = await reservations.createReservation(
        fieldId: field.id,
        userId: userId,
        startTime: start,
        endTime: end,
      );
      emit(
        ReservationFormSucceeded(
          created,
          startText: current.startText,
          endText: current.endText,
        ),
      );
    } on ServerUnreachableException catch (error) {
      emit(
        ReservationFormFailed(
          describeError(error),
          startText: current.startText,
          endText: current.endText,
        ),
      );
    } catch (error) {
      // Server (ili pravilo) je odbio zahtev. Unos ostaje, a podaci za proveru
      // se ponovo učitavaju, jer su verovatno zastareli (npr. termin je zauzet).
      emit(
        ReservationFormRejected(
          describeError(error),
          startText: current.startText,
          endText: current.endText,
        ),
      );
      await _reloadQuietly();
    }
  }

  Future<void> _reloadQuietly() async {
    try {
      _context = await _loadCheckData();
    } catch (_) {
      // Ostaje stari podaci; sledeća izmena unosa ili novo slanje to ponavlja.
    }
  }
}

/// Podaci za lokalnu proveru termina.
final class _CheckData {
  final List<FieldSchedule> schedules;
  final List<BlockedPeriod> blockedPeriods;
  final List<Reservation> ownReservations;

  const _CheckData({
    this.schedules = const [],
    this.blockedPeriods = const [],
    this.ownReservations = const [],
  });
}
