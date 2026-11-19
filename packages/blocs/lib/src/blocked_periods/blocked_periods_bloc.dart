import 'package:bloc/bloc.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

// --- događaji -------------------------------------------------------------

sealed class BlockedPeriodsEvent extends Equatable {
  const BlockedPeriodsEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj terene vlasnika i blokade izabranog terena. Šalje se na početku i za
/// „Pokušaj ponovo“.
final class BlockedPeriodsStarted extends BlockedPeriodsEvent {
  const BlockedPeriodsStarted();
}

final class BlockedPeriodsFieldSelected extends BlockedPeriodsEvent {
  final FieldId fieldId;

  const BlockedPeriodsFieldSelected(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

/// Vlasnik blokira teren od [startTime] do [endTime].
final class BlockedPeriodAddRequested extends BlockedPeriodsEvent {
  final DateTime startTime;
  final DateTime endTime;
  final String? reason;

  const BlockedPeriodAddRequested({
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  @override
  List<Object?> get props => [startTime, endTime, reason];
}

final class BlockedPeriodRemoveRequested extends BlockedPeriodsEvent {
  final BlockedPeriod period;

  const BlockedPeriodRemoveRequested(this.period);

  @override
  List<Object?> get props => [period.id];
}

// --- stanja ---------------------------------------------------------------

sealed class BlockedPeriodsState extends Equatable {
  const BlockedPeriodsState();

  @override
  List<Object?> get props => [];
}

final class BlockedPeriodsLoading extends BlockedPeriodsState {
  const BlockedPeriodsLoading();
}

final class BlockedPeriodsError extends BlockedPeriodsState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const BlockedPeriodsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Vlasnik nema nijedan teren, pa nema šta da blokira.
final class BlockedPeriodsNoFields extends BlockedPeriodsState {
  const BlockedPeriodsNoFields();
}

final class BlockedPeriodsLoaded extends BlockedPeriodsState {
  /// Tereni vlasnika; blokirati može samo njih.
  final List<SportsField> fields;

  /// Izabrani teren.
  final SportsField field;

  /// Blokade izabranog terena koje traju ili tek dolaze, po početku.
  final List<BlockedPeriod> blocks;

  /// Dodavanje ili brisanje je u toku.
  final bool busy;

  /// Poruka o poslednjoj radnji koja nije uspela (razlog), ili `null`.
  final String? message;

  BlockedPeriodsLoaded({
    required List<SportsField> fields,
    required this.field,
    required List<BlockedPeriod> blocks,
    this.busy = false,
    this.message,
  }) : fields = List.unmodifiable(fields),
       blocks = List.unmodifiable(blocks);

  BlockedPeriodsLoaded copyWith({
    List<BlockedPeriod>? blocks,
    bool? busy,
    String? message,
    bool clearMessage = false,
  }) => BlockedPeriodsLoaded(
    fields: fields,
    field: field,
    blocks: blocks ?? this.blocks,
    busy: busy ?? this.busy,
    message: clearMessage ? null : (message ?? this.message),
  );

  @override
  List<Object?> get props => [
    [for (final f in fields) f.id],
    field.id,
    [for (final b in blocks) (b.id, b.startTime, b.endTime, b.reason)],
    busy,
    message,
  ];
}

// --- Bloc -----------------------------------------------------------------

/// Blokiranje termina (održavanje, događaji) za vlasnika.
///
/// Pravilo je isto kao na serveru (`validateBlockedPeriod`): blokada ne sme
/// preko potvrđene rezervacije, a razlog odbijanja se prikazuje onako kako ga
/// piše `describeError`. Vlasnik vidi i blokira samo svoje terene
/// (`canManageField`).
final class BlockedPeriodsBloc
    extends Bloc<BlockedPeriodsEvent, BlockedPeriodsState> {
  final SportsFieldRepository fields;
  final FieldScheduleRepository schedules;
  final ReservationRepository reservations;
  final AppUser owner;
  final DateTime Function() _clock;

  static const _forbidden = ErrorDto(code: ErrorCodes.forbidden);

  // Raste sa svakim učitavanjem: odgovor starijeg zahteva se odbacuje.
  var _request = 0;

  BlockedPeriodsBloc({
    required this.fields,
    required this.schedules,
    required this.reservations,
    required this.owner,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const BlockedPeriodsLoading()) {
    on<BlockedPeriodsStarted>(_onStarted);
    on<BlockedPeriodsFieldSelected>(_onFieldSelected);
    on<BlockedPeriodAddRequested>(_onAddRequested);
    on<BlockedPeriodRemoveRequested>(_onRemoveRequested);
  }

  Future<void> _onStarted(
    BlockedPeriodsStarted event,
    Emitter<BlockedPeriodsState> emit,
  ) async {
    final request = ++_request;
    final selected = switch (state) {
      BlockedPeriodsLoaded(:final field) => field.id,
      _ => null,
    };
    emit(const BlockedPeriodsLoading());

    try {
      final own = await fields.getFieldsByOwner(owner.id);
      if (request != _request) return;

      if (own.isEmpty) {
        emit(const BlockedPeriodsNoFields());
        return;
      }

      final field = own.firstWhere(
        (candidate) => candidate.id == selected,
        orElse: () => own.first,
      );
      final blocks = await _upcoming(field);
      if (request != _request) return;

      emit(BlockedPeriodsLoaded(fields: own, field: field, blocks: blocks));
    } catch (error) {
      if (request != _request) return;
      emit(BlockedPeriodsError(describeError(error)));
    }
  }

  Future<void> _onFieldSelected(
    BlockedPeriodsFieldSelected event,
    Emitter<BlockedPeriodsState> emit,
  ) async {
    final current = state;
    if (current is! BlockedPeriodsLoaded || current.busy) return;

    // Samo teren koji vlasnik ima; tuđi se ne bira.
    final field = current.fields
        .where((candidate) => candidate.id == event.fieldId)
        .firstOrNull;
    if (field == null) return;

    final request = ++_request;
    try {
      final blocks = await _upcoming(field);
      if (request != _request) return;

      emit(
        BlockedPeriodsLoaded(
          fields: current.fields,
          field: field,
          blocks: blocks,
        ),
      );
    } catch (error) {
      if (request != _request) return;
      emit(BlockedPeriodsError(describeError(error)));
    }
  }

  Future<void> _onAddRequested(
    BlockedPeriodAddRequested event,
    Emitter<BlockedPeriodsState> emit,
  ) async {
    final current = state;
    if (current is! BlockedPeriodsLoaded || current.busy) return;

    if (!canManageField(owner, current.field)) {
      emit(current.copyWith(message: errorMessage(_forbidden)));
      return;
    }

    emit(current.copyWith(busy: true, clearMessage: true));

    try {
      // Rezervacije terena (sveže), da lokalna provera vidi ono što server vidi.
      final now = _clock();
      final onField = await reservations.getReservationsByField(
        current.field.id,
      );
      final error = validateBlockedPeriod(
        fieldId: current.field.id,
        startTime: event.startTime,
        endTime: event.endTime,
        now: now,
        reservations: [
          for (final r in onField)
            r.copyWith(status: resolveReservationStatus(r, now)),
        ],
      );

      // Neispravnu blokadu ne šaljemo; razlog se prikazuje odmah.
      if (error != null) {
        emit(
          current.copyWith(
            busy: false,
            message: describeError(BlockedPeriodRuleViolation(error)),
          ),
        );
        return;
      }

      final reason = event.reason?.trim();
      await schedules.addBlockedPeriod(
        BlockedPeriod(
          fieldId: current.field.id,
          startTime: event.startTime,
          endTime: event.endTime,
          reason: reason == null || reason.isEmpty ? null : reason,
        ),
      );
    } catch (error) {
      // Server je odbio (ili nema mreže). Spisak se ponovo učitava, jer je
      // verovatno zastareo (npr. rezervacija je u međuvremenu potvrđena).
      await _reload(emit, current, message: describeError(error));
      return;
    }

    await _reload(emit, current);
  }

  Future<void> _onRemoveRequested(
    BlockedPeriodRemoveRequested event,
    Emitter<BlockedPeriodsState> emit,
  ) async {
    final current = state;
    if (current is! BlockedPeriodsLoaded || current.busy) return;

    final id = event.period.id;
    if (id == null || event.period.fieldId != current.field.id) return;

    if (!canManageField(owner, current.field)) {
      emit(current.copyWith(message: errorMessage(_forbidden)));
      return;
    }

    emit(current.copyWith(busy: true, clearMessage: true));

    try {
      await schedules.removeBlockedPeriod(current.field.id, id);
    } catch (error) {
      await _reload(emit, current, message: describeError(error));
      return;
    }

    await _reload(emit, current);
  }

  /// Ponovo učitava blokade izabranog terena; [message] ostaje uz spisak.
  Future<void> _reload(
    Emitter<BlockedPeriodsState> emit,
    BlockedPeriodsLoaded current, {
    String? message,
  }) async {
    try {
      final blocks = await _upcoming(current.field);
      emit(
        BlockedPeriodsLoaded(
          fields: current.fields,
          field: current.field,
          blocks: blocks,
          message: message,
        ),
      );
    } catch (error) {
      emit(BlockedPeriodsError(describeError(error)));
    }
  }

  Future<List<BlockedPeriod>> _upcoming(SportsField field) async {
    final blocks = await schedules.getBlockedPeriods(field.id, from: _clock());

    return [...blocks]..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}
