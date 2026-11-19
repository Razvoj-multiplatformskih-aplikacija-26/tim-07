import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

// --- događaji -------------------------------------------------------------

sealed class AvailabilityEvent extends Equatable {
  const AvailabilityEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj termine za izabrani dan. Šalje se na početku, za „Pokušaj ponovo“ i
/// kada se korisnik vrati sa forme za rezervaciju (termin je možda zauzet).
final class AvailabilityRequested extends AvailabilityEvent {
  const AvailabilityRequested();
}

/// Korisnik je izabrao drugi dan.
final class AvailabilityDaySelected extends AvailabilityEvent {
  final DateTime day;

  const AvailabilityDaySelected(this.day);

  @override
  List<Object?> get props => [day];
}

// --- stanja ---------------------------------------------------------------

/// Termini jednog terena za jedan dan. Svako stanje nosi dan, pa ga ni
/// učitavanje ni greška ne brišu.
sealed class AvailabilityState extends Equatable {
  /// Kalendarski dan (bez sata).
  final DateTime day;

  const AvailabilityState({required this.day});

  @override
  List<Object?> get props => [day];
}

final class AvailabilityLoading extends AvailabilityState {
  const AvailabilityLoading({required super.day});
}

final class AvailabilityError extends AvailabilityState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const AvailabilityError(this.message, {required super.day});

  @override
  List<Object?> get props => [...super.props, message];
}

/// Teren tog dana ne radi, pa nema nijednog termina. Nije isto što i dan u
/// kome su svi termini zauzeti.
final class AvailabilityEmpty extends AvailabilityState {
  const AvailabilityEmpty({required super.day});
}

final class AvailabilityLoaded extends AvailabilityState {
  final List<AvailabilitySlot> slots;

  AvailabilityLoaded({
    required List<AvailabilitySlot> slots,
    required super.day,
  }) : slots = List.unmodifiable(slots);

  int get freeCount => slots.where((slot) => slot.isFree).length;

  @override
  List<Object?> get props => [
    ...super.props,
    [for (final slot in slots) (slot.startTime, slot.endTime, slot.state)],
  ];
}

// --- Bloc -----------------------------------------------------------------

/// Slobodni termini jednog terena. Termine ne pravi sam (ni fiksna lista sati):
/// dobija ih od `AvailabilityRepository`, koji ih računa iz radnog vremena,
/// rezervacija i blokada.
final class AvailabilityBloc
    extends Bloc<AvailabilityEvent, AvailabilityState> {
  final AvailabilityRepository repository;
  final FieldId fieldId;

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  AvailabilityBloc({
    required this.repository,
    required this.fieldId,
    DateTime Function()? clock,
  }) : super(AvailabilityLoading(day: _dayOf((clock ?? DateTime.now)()))) {
    on<AvailabilityRequested>((event, emit) => _load(emit, state.day));
    on<AvailabilityDaySelected>(
      (event, emit) => _load(emit, _dayOf(event.day)),
    );
  }

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  Future<void> _load(Emitter<AvailabilityState> emit, DateTime day) async {
    final request = ++_request;
    emit(AvailabilityLoading(day: day));

    try {
      final slots = await repository.getAvailability(
        fieldId: fieldId,
        date: day,
      );
      if (request != _request) return;

      emit(
        slots.isEmpty
            ? AvailabilityEmpty(day: day)
            : AvailabilityLoaded(slots: slots, day: day),
      );
    } catch (error) {
      if (request != _request) return;
      emit(AvailabilityError(describeError(error), day: day));
    }
  }
}
