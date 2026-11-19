import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

/// Opseg kalendara.
enum CalendarView { day, week }

// --- događaji -------------------------------------------------------------

sealed class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj terene vlasnika i kalendar za današnji dan. Šalje se na početku i za
/// „Pokušaj ponovo“ posle greške pri učitavanju terena.
final class CalendarStarted extends CalendarEvent {
  const CalendarStarted();
}

final class CalendarViewChanged extends CalendarEvent {
  final CalendarView view;

  const CalendarViewChanged(this.view);

  @override
  List<Object?> get props => [view];
}

/// Pomeri opseg za [steps] dana (dnevni prikaz) ili nedelja (nedeljni prikaz).
final class CalendarMoved extends CalendarEvent {
  final int steps;

  const CalendarMoved(this.steps);

  @override
  List<Object?> get props => [steps];
}

final class CalendarTodayRequested extends CalendarEvent {
  const CalendarTodayRequested();
}

/// Idi na dan koji je vlasnik izabrao (sat se ignoriše).
final class CalendarDateSelected extends CalendarEvent {
  final DateTime date;

  const CalendarDateSelected(this.date);

  @override
  List<Object?> get props => [date];
}

/// Nedeljni prikaz prikazuje jedan teren; ovo menja koji.
final class CalendarFieldSelected extends CalendarEvent {
  final FieldId fieldId;

  const CalendarFieldSelected(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

/// Ponovo učitaj isti opseg, na primer posle potvrde ili otkazivanja
/// rezervacije ili za „Pokušaj ponovo“ posle greške.
final class CalendarRefreshed extends CalendarEvent {
  const CalendarRefreshed();
}

// --- stanja ---------------------------------------------------------------

sealed class CalendarState extends Equatable {
  const CalendarState();

  @override
  List<Object?> get props => [];
}

final class CalendarLoading extends CalendarState {
  const CalendarLoading();
}

final class CalendarError extends CalendarState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const CalendarError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Vlasnik nema nijedan teren, pa nema šta da prikaže.
final class CalendarNoFields extends CalendarState {
  const CalendarNoFields();
}

final class CalendarLoaded extends CalendarState {
  final CalendarView view;

  /// Dan koji je izabran. U nedeljnom prikazu je to bilo koji dan te nedelje.
  final DateTime date;

  /// Tereni vlasnika, po redosledu iz izvora.
  final List<SportsField> fields;

  /// Teren nedeljnog prikaza. U dnevnom prikazu su svi tereni.
  final SportsField field;

  /// Prvi dan opsega (ponoć): izabrani dan ili ponedeljak te nedelje.
  final DateTime rangeStart;

  /// Prvi dan posle opsega.
  final DateTime rangeEnd;

  /// Kolone kalendara: tereni (dnevni prikaz) ili dani (nedeljni prikaz).
  final List<FieldCalendarDay> days;

  /// Rezervacije opsega, da ekran nađe onu koju je vlasnik izabrao.
  final List<Reservation> reservations;

  /// Trenutak u kome su podaci izračunati (sat Bloc-a), da ekran ne pita sat.
  final DateTime now;

  /// Opseg se učitava; [days] još nisu za taj opseg.
  final bool refreshing;

  /// Poruka kada učitavanje opsega nije uspelo, inače `null`.
  final String? message;

  CalendarLoaded({
    required this.view,
    required this.date,
    required List<SportsField> fields,
    required this.field,
    required this.rangeStart,
    required this.rangeEnd,
    required List<FieldCalendarDay> days,
    required List<Reservation> reservations,
    required this.now,
    this.refreshing = false,
    this.message,
  }) : fields = List.unmodifiable(fields),
       days = List.unmodifiable(days),
       reservations = List.unmodifiable(reservations);

  /// Broj dana u opsegu.
  int get dayCount => rangeEnd.difference(rangeStart).inDays;

  CalendarLoaded copyWith({
    bool? refreshing,
    String? message,
    bool clearMessage = false,
  }) => CalendarLoaded(
    view: view,
    date: date,
    fields: fields,
    field: field,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    days: days,
    reservations: reservations,
    now: now,
    refreshing: refreshing ?? this.refreshing,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [
    view,
    date,
    [for (final f in fields) f.id],
    field.id,
    rangeStart,
    rangeEnd,
    days,
    [for (final r in reservations) (r.id, r.status)],
    now,
    refreshing,
    message,
  ];
}

// --- Bloc -----------------------------------------------------------------

/// Dnevni i nedeljni kalendar rezervacija za vlasnika.
///
/// Bloc drži opseg (dan ili nedelja), izabrani teren nedeljnog prikaza i
/// podatke tog opsega. Redove kalendara računa domen (`buildFieldCalendarDay`)
/// iz radnog vremena, rezervacija i blokada, pa kalendar i aplikacija za
/// korisnike ne mogu da se razilaze. Vlasnik vidi samo svoje terene.
final class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  final SportsFieldRepository fields;
  final FieldScheduleRepository schedules;
  final ReservationRepository reservations;
  final AppUser owner;
  final DateTime Function() _clock;

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  CalendarBloc({
    required this.fields,
    required this.schedules,
    required this.reservations,
    required this.owner,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const CalendarLoading()) {
    on<CalendarStarted>(_onStarted);
    on<CalendarViewChanged>(_onViewChanged);
    on<CalendarMoved>(_onMoved);
    on<CalendarTodayRequested>(_onToday);
    on<CalendarDateSelected>(_onDateSelected);
    on<CalendarFieldSelected>(_onFieldSelected);
    on<CalendarRefreshed>(_onRefreshed);
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  static DateTime _addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  /// Ponedeljak nedelje u kojoj je [day].
  static DateTime weekStart(DateTime day) =>
      _addDays(_dayOf(day), 1 - day.weekday);

  Future<void> _onStarted(
    CalendarStarted event,
    Emitter<CalendarState> emit,
  ) async {
    final request = ++_request;
    final previous = state;
    emit(const CalendarLoading());

    try {
      final own = await fields.getFieldsByOwner(owner.id);
      if (request != _request) return;

      if (own.isEmpty) {
        emit(const CalendarNoFields());
        return;
      }

      final view = previous is CalendarLoaded
          ? previous.view
          : CalendarView.day;
      final date = previous is CalendarLoaded
          ? previous.date
          : _dayOf(_clock());
      final field = previous is CalendarLoaded
          ? own.firstWhere(
              (candidate) => candidate.id == previous.field.id,
              orElse: () => own.first,
            )
          : own.first;

      emit(await _load(own, field, view, date));
    } catch (error) {
      if (request != _request) return;
      emit(CalendarError(describeError(error)));
    }
  }

  /// Promena opsega: ekran odmah dobija novi opseg uz `refreshing`, pa podatke.
  Future<void> _change(
    Emitter<CalendarState> emit, {
    CalendarView? view,
    DateTime? date,
    SportsField? field,
  }) async {
    final current = state;
    if (current is! CalendarLoaded) return;

    final request = ++_request;
    final nextView = view ?? current.view;
    final nextDate = _dayOf(date ?? current.date);
    final nextField = field ?? current.field;

    // Isti opseg (osvežavanje) zadržava podatke dok novi ne stignu; drugi opseg
    // ih odmah briše, da kolone ne budu pod naslovom drugog dana.
    final sameRange =
        nextView == current.view &&
        nextDate == current.date &&
        nextField.id == current.field.id;
    final pending = sameRange
        ? current.copyWith(refreshing: true, clearMessage: true)
        : _pending(current, nextView, nextDate, nextField);

    emit(pending);

    try {
      final loaded = await _load(current.fields, nextField, nextView, nextDate);
      if (request != _request) return;
      emit(loaded);
    } catch (error) {
      if (request != _request) return;
      emit(pending.copyWith(refreshing: false, message: describeError(error)));
    }
  }

  CalendarLoaded _pending(
    CalendarLoaded current,
    CalendarView view,
    DateTime date,
    SportsField field,
  ) {
    final (start, end) = _range(view, date);

    return CalendarLoaded(
      view: view,
      date: date,
      fields: current.fields,
      field: field,
      rangeStart: start,
      rangeEnd: end,
      days: const [],
      reservations: const [],
      now: current.now,
      refreshing: true,
    );
  }

  static (DateTime, DateTime) _range(CalendarView view, DateTime date) {
    final start = view == CalendarView.week ? weekStart(date) : _dayOf(date);

    return (start, _addDays(start, view == CalendarView.week ? 7 : 1));
  }

  Future<CalendarLoaded> _load(
    List<SportsField> own,
    SportsField field,
    CalendarView view,
    DateTime date,
  ) async {
    final now = _clock();
    final (start, end) = _range(view, date);

    // Dnevni prikaz: svi tereni jednog dana. Nedeljni: jedan teren, sedam dana.
    final shown = view == CalendarView.day ? own : [field];

    final perField = await Future.wait([
      for (final candidate in shown)
        _fieldData(candidate, start: start, end: end),
    ]);

    final days = <FieldCalendarDay>[];
    final allReservations = <Reservation>[];

    for (final data in perField) {
      allReservations.addAll(data.reservations);

      for (var day = start; day.isBefore(end); day = _addDays(day, 1)) {
        days.add(
          buildFieldCalendarDay(
            fieldId: data.field.id,
            date: day,
            schedules: data.schedules,
            reservations: data.reservations,
            blockedPeriods: data.blocks,
            now: now,
          ),
        );
      }
    }

    return CalendarLoaded(
      view: view,
      date: _dayOf(date),
      fields: own,
      field: field,
      rangeStart: start,
      rangeEnd: end,
      days: days,
      reservations: allReservations,
      now: now,
    );
  }

  Future<_FieldData> _fieldData(
    SportsField field, {
    required DateTime start,
    required DateTime end,
  }) async {
    final results = await Future.wait<Object>([
      schedules.getSchedules(field.id),
      schedules.getBlockedPeriods(field.id, from: start, to: end),
      reservations.getReservationsByField(field.id),
    ]);

    return _FieldData(
      field: field,
      schedules: results[0] as List<FieldSchedule>,
      blocks: results[1] as List<BlockedPeriod>,
      reservations: results[2] as List<Reservation>,
    );
  }

  Future<void> _onViewChanged(
    CalendarViewChanged event,
    Emitter<CalendarState> emit,
  ) {
    final current = state;
    if (current is CalendarLoaded && current.view == event.view) {
      return Future.value();
    }
    return _change(emit, view: event.view);
  }

  Future<void> _onMoved(CalendarMoved event, Emitter<CalendarState> emit) {
    final current = state;
    if (current is! CalendarLoaded || event.steps == 0) return Future.value();

    final days = current.view == CalendarView.week ? 7 : 1;
    return _change(emit, date: _addDays(current.date, event.steps * days));
  }

  Future<void> _onToday(
    CalendarTodayRequested event,
    Emitter<CalendarState> emit,
  ) => _change(emit, date: _dayOf(_clock()));

  Future<void> _onDateSelected(
    CalendarDateSelected event,
    Emitter<CalendarState> emit,
  ) => _change(emit, date: event.date);

  Future<void> _onFieldSelected(
    CalendarFieldSelected event,
    Emitter<CalendarState> emit,
  ) {
    final current = state;
    if (current is! CalendarLoaded) return Future.value();

    final field = current.fields.where((f) => f.id == event.fieldId);
    // Tuđ ili nepoznat teren se ne prihvata: vlasnik vidi samo svoje.
    if (field.isEmpty) return Future.value();

    return _change(emit, field: field.first);
  }

  Future<void> _onRefreshed(
    CalendarRefreshed event,
    Emitter<CalendarState> emit,
  ) {
    final current = state;
    if (current is CalendarLoaded) return _change(emit);
    if (current is CalendarError) {
      return _onStarted(const CalendarStarted(), emit);
    }
    return Future.value();
  }
}

final class _FieldData {
  final SportsField field;
  final List<FieldSchedule> schedules;
  final List<BlockedPeriod> blocks;
  final List<Reservation> reservations;

  const _FieldData({
    required this.field,
    required this.schedules,
    required this.blocks,
    required this.reservations,
  });
}
