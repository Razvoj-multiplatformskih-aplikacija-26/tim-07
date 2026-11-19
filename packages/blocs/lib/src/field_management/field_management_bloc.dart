import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

final class FieldDraft extends Equatable {
  final String name;
  final String description;
  final SportType sport;
  final String address;
  final String city;
  final int pricePerHour;
  final String contactPhone;
  final ConfirmationMode confirmationMode;
  final bool isActive;

  const FieldDraft({
    required this.name,
    required this.description,
    required this.sport,
    required this.address,
    required this.city,
    required this.pricePerHour,
    required this.contactPhone,
    required this.confirmationMode,
    this.isActive = true,
  });

  factory FieldDraft.of(SportsField field) => FieldDraft(
    name: field.name,
    description: field.description,
    sport: field.sport,
    address: field.address,
    city: field.city,
    pricePerHour: field.pricePerHour,
    contactPhone: field.contactPhone,
    confirmationMode: field.confirmationMode,
    isActive: field.isActive,
  );

  Set<FieldDataError> get errors => validateFieldDetails(
    name: name,
    address: address,
    city: city,
    pricePerHour: pricePerHour,
    contactPhone: contactPhone,
  );

  @override
  List<Object?> get props => [
    name,
    description,
    sport,
    address,
    city,
    pricePerHour,
    contactPhone,
    confirmationMode,
    isActive,
  ];
}

sealed class FieldManagementEvent extends Equatable {
  const FieldManagementEvent();

  @override
  List<Object?> get props => [];
}

final class FieldManagementStarted extends FieldManagementEvent {
  const FieldManagementStarted();
}

final class FieldManagementFieldSelected extends FieldManagementEvent {
  final FieldId fieldId;

  const FieldManagementFieldSelected(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

final class FieldSaveRequested extends FieldManagementEvent {
  final FieldDraft draft;
  final FieldId? fieldId;

  const FieldSaveRequested(this.draft, {this.fieldId});

  @override
  List<Object?> get props => [draft, fieldId];
}

final class FieldScheduleSaveRequested extends FieldManagementEvent {
  final List<FieldSchedule> schedules;

  const FieldScheduleSaveRequested(this.schedules);

  @override
  List<Object?> get props => [
    [for (final s in schedules) (s.dayOfWeek, s.opensAt.totalMinutes, s.closesAt.totalMinutes, s.isOpen)],
  ];
}

sealed class FieldManagementState extends Equatable {
  const FieldManagementState();

  @override
  List<Object?> get props => [];
}

final class FieldManagementLoading extends FieldManagementState {
  const FieldManagementLoading();
}

final class FieldManagementError extends FieldManagementState {
  final String message;

  const FieldManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

final class FieldManagementEmpty extends FieldManagementState {
  final bool busy;
  final String? message;

  const FieldManagementEmpty({this.busy = false, this.message});

  @override
  List<Object?> get props => [busy, message];
}

final class FieldManagementLoaded extends FieldManagementState {
  final List<SportsField> fields;
  final SportsField field;
  final List<FieldSchedule> schedules;
  final bool busy;
  final String? message;
  final bool success;

  FieldManagementLoaded({
    required List<SportsField> fields,
    required this.field,
    required List<FieldSchedule> schedules,
    this.busy = false,
    this.message,
    this.success = false,
  }) : fields = List.unmodifiable(fields),
       schedules = List.unmodifiable(schedules);

  FieldManagementLoaded copyWith({bool? busy, String? message, bool? success}) => FieldManagementLoaded(
    fields: fields,
    field: field,
    schedules: schedules,
    busy: busy ?? this.busy,
    message: message,
    success: success ?? false,
  );

  @override
  List<Object?> get props => [
    [for (final f in fields) (f.id, f.name, f.approvalStatus, f.isActive, f.pricePerHour)],
    field.id,
    [for (final s in schedules) (s.dayOfWeek, s.opensAt.totalMinutes, s.closesAt.totalMinutes, s.isOpen)],
    busy,
    message,
    success,
  ];
}

final class FieldManagementBloc extends Bloc<FieldManagementEvent, FieldManagementState> {
  final SportsFieldRepository fields;
  final FieldScheduleRepository schedules;
  final AppUser owner;

  var _request = 0;

  FieldManagementBloc({required this.fields, required this.schedules, required this.owner})
    : super(const FieldManagementLoading()) {
    on<FieldManagementStarted>(_onStarted);
    on<FieldManagementFieldSelected>(_onSelected);
    on<FieldSaveRequested>(_onSave);
    on<FieldScheduleSaveRequested>(_onScheduleSave);
  }

  Future<void> _load(
    Emitter<FieldManagementState> emit, {
    FieldId? select,
    String? message,
    bool success = false,
  }) async {
    final request = ++_request;
    try {
      final own = await fields.getFieldsByOwner(owner.id);
      if (request != _request) return;
      if (own.isEmpty) {
        emit(FieldManagementEmpty(message: message));
        return;
      }
      final field = own.firstWhere((f) => f.id == select, orElse: () => own.first);
      final schedule = await schedules.getSchedules(field.id);
      if (request != _request) return;
      emit(
        FieldManagementLoaded(
          fields: own,
          field: field,
          schedules: schedule,
          message: message,
          success: success,
        ),
      );
    } catch (error) {
      if (request != _request) return;
      emit(FieldManagementError(describeError(error)));
    }
  }

  Future<void> _onStarted(FieldManagementStarted event, Emitter<FieldManagementState> emit) async {
    final selected = switch (state) {
      FieldManagementLoaded(:final field) => field.id,
      _ => null,
    };
    emit(const FieldManagementLoading());
    await _load(emit, select: selected);
  }

  Future<void> _onSelected(FieldManagementFieldSelected event, Emitter<FieldManagementState> emit) async {
    final current = state;
    if (current is FieldManagementLoaded && current.busy) return;
    await _load(emit, select: event.fieldId);
  }

  Future<void> _onSave(FieldSaveRequested event, Emitter<FieldManagementState> emit) async {
    final current = state;
    if (event.draft.errors.isNotEmpty) return;
    _setBusy(emit, current);
    try {
      final draft = event.draft;
      final SportsField saved;
      if (event.fieldId case final id?) {
        final existing = await fields.getFieldById(id);
        if (existing == null) throw EntityNotFound('field', id.value);
        saved = await fields.updateField(
          existing.copyWith(
            name: draft.name.trim(),
            description: draft.description.trim(),
            sport: draft.sport,
            address: draft.address.trim(),
            city: draft.city.trim(),
            pricePerHour: draft.pricePerHour,
            contactPhone: draft.contactPhone.trim(),
            confirmationMode: draft.confirmationMode,
            isActive: draft.isActive,
          ),
        );
      } else {
        saved = await fields.createField(
          ownerId: owner.id,
          name: draft.name.trim(),
          description: draft.description.trim(),
          sport: draft.sport,
          address: draft.address.trim(),
          city: draft.city.trim(),
          pricePerHour: draft.pricePerHour,
          contactPhone: draft.contactPhone.trim(),
          confirmationMode: draft.confirmationMode,
        );
      }
      await _load(emit, select: saved.id, message: 'Teren je sačuvan.', success: true);
    } catch (error) {
      await _load(emit, select: event.fieldId, message: describeError(error));
    }
  }

  Future<void> _onScheduleSave(FieldScheduleSaveRequested event, Emitter<FieldManagementState> emit) async {
    final current = state;
    if (current is! FieldManagementLoaded || current.busy) return;
    if (validateFieldSchedule(fieldId: current.field.id, schedules: event.schedules) != null) return;
    emit(current.copyWith(busy: true));
    try {
      await schedules.replaceSchedules(current.field.id, event.schedules);
      await _load(emit, select: current.field.id, message: 'Radno vreme je sačuvano.', success: true);
    } catch (error) {
      await _load(emit, select: current.field.id, message: describeError(error));
    }
  }

  void _setBusy(Emitter<FieldManagementState> emit, FieldManagementState current) {
    switch (current) {
      case FieldManagementLoaded():
        emit(current.copyWith(busy: true));
      case FieldManagementEmpty():
        emit(const FieldManagementEmpty(busy: true));
      default:
        break;
    }
  }
}
