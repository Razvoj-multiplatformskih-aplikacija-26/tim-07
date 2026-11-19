import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

sealed class FieldReviewEvent extends Equatable {
  const FieldReviewEvent();

  @override
  List<Object?> get props => [];
}

final class FieldReviewStarted extends FieldReviewEvent {
  const FieldReviewStarted();
}

final class FieldReviewDecided extends FieldReviewEvent {
  final FieldId fieldId;
  final ApprovalStatus decision;
  final String? reason;

  const FieldReviewDecided(this.fieldId, this.decision, {this.reason});

  @override
  List<Object?> get props => [fieldId, decision, reason];
}

sealed class FieldReviewState extends Equatable {
  const FieldReviewState();

  @override
  List<Object?> get props => [];
}

final class FieldReviewLoading extends FieldReviewState {
  const FieldReviewLoading();
}

final class FieldReviewError extends FieldReviewState {
  final String message;

  const FieldReviewError(this.message);

  @override
  List<Object?> get props => [message];
}

final class FieldReviewLoaded extends FieldReviewState {
  final List<SportsField> waiting;
  final bool busy;
  final String? message;

  FieldReviewLoaded({required List<SportsField> waiting, this.busy = false, this.message})
    : waiting = List.unmodifiable(waiting);

  @override
  List<Object?> get props => [
    [for (final f in waiting) f.id],
    busy,
    message,
  ];
}

final class FieldReviewBloc extends Bloc<FieldReviewEvent, FieldReviewState> {
  final SportsFieldRepository fields;
  final AppUser reviewer;

  FieldReviewBloc({required this.fields, required this.reviewer}) : super(const FieldReviewLoading()) {
    on<FieldReviewStarted>((event, emit) => _load(emit));
    on<FieldReviewDecided>(_onDecided);
  }

  Future<void> _load(Emitter<FieldReviewState> emit, {String? message}) async {
    try {
      emit(FieldReviewLoaded(waiting: await fields.getFieldsAwaitingApproval(), message: message));
    } catch (error) {
      emit(FieldReviewError(describeError(error)));
    }
  }

  Future<void> _onDecided(FieldReviewDecided event, Emitter<FieldReviewState> emit) async {
    final current = state;
    if (current is! FieldReviewLoaded || current.busy || !canReviewField(reviewer)) return;
    emit(FieldReviewLoaded(waiting: current.waiting, busy: true));
    try {
      final reviewed = await fields.reviewField(
        fieldId: event.fieldId,
        reviewerId: reviewer.id,
        decision: event.decision,
        reason: event.reason,
      );
      final verb = event.decision == ApprovalStatus.approved ? 'odobren' : 'odbijen';
      await _load(emit, message: 'Teren „${reviewed.name}“ je $verb.');
    } catch (error) {
      await _load(emit, message: describeError(error));
    }
  }
}
