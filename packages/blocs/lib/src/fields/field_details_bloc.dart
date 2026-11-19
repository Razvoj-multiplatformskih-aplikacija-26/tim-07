import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

/// Detalj jednog terena za adresu `/fields/:fieldId`.
sealed class FieldDetailsEvent extends Equatable {
  const FieldDetailsEvent();

  @override
  List<Object?> get props => [];
}

/// Učitaj teren (i „Pokušaj ponovo“).
final class FieldDetailsRequested extends FieldDetailsEvent {
  final FieldId fieldId;

  const FieldDetailsRequested(this.fieldId);

  @override
  List<Object?> get props => [fieldId];
}

sealed class FieldDetailsState extends Equatable {
  const FieldDetailsState();

  @override
  List<Object?> get props => [];
}

final class FieldDetailsLoading extends FieldDetailsState {
  const FieldDetailsLoading();
}

final class FieldDetailsLoaded extends FieldDetailsState {
  final SportsField field;

  const FieldDetailsLoaded(this.field);

  @override
  List<Object?> get props => [field];
}

/// Teren ne postoji ili nije javan. Za korisnika je to isto: ne vidi ga.
final class FieldDetailsNotFound extends FieldDetailsState {
  const FieldDetailsNotFound();
}

final class FieldDetailsError extends FieldDetailsState {
  /// Poruka za korisnika (nikad tehnički tekst).
  final String message;

  const FieldDetailsError(this.message);

  @override
  List<Object?> get props => [message];
}

final class FieldDetailsBloc
    extends Bloc<FieldDetailsEvent, FieldDetailsState> {
  final SportsFieldRepository repository;

  var _request = 0;

  FieldDetailsBloc({required this.repository})
    : super(const FieldDetailsLoading()) {
    on<FieldDetailsRequested>(_onRequested);
  }

  Future<void> _onRequested(
    FieldDetailsRequested event,
    Emitter<FieldDetailsState> emit,
  ) async {
    final request = ++_request;
    emit(const FieldDetailsLoading());

    try {
      final field = await repository.getFieldById(event.fieldId);
      if (request != _request) return;

      // Neodobren ili neaktivan teren nije u javnom katalogu, pa ga posetilac
      // ne vidi ni preko adrese.
      emit(
        field == null || !isFieldPublic(field)
            ? const FieldDetailsNotFound()
            : FieldDetailsLoaded(field),
      );
    } catch (error) {
      if (request != _request) return;
      emit(FieldDetailsError(describeError(error)));
    }
  }
}
