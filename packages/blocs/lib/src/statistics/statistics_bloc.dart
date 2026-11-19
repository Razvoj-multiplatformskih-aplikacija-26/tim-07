import 'package:bloc/bloc.dart';
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';
import 'package:messages/messages.dart';

final class LocalStatisticsRepository implements StatisticsRepository {
  final SportsFieldRepository fields;
  final FieldScheduleRepository schedules;
  final ReservationRepository reservations;
  final AppUser viewer;
  final DateTime Function() _clock;

  LocalStatisticsRepository({
    required this.fields,
    required this.schedules,
    required this.reservations,
    required this.viewer,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  Future<OccupancyReport> getOccupancy({required StatsPeriod period, UserId? ownerId}) async {
    final visible = [
      for (final field in await fields.getFields())
        if (canViewFieldStatistics(viewer, field)) field,
    ];
    final now = _clock();
    final all = await reservations.getReservations();
    return calculateOccupancyReport(
      period: period,
      fields: visible,
      schedules: [for (final field in visible) ...await schedules.getSchedules(field.id)],
      reservations: [
        for (final reservation in all) reservation.copyWith(status: resolveReservationStatus(reservation, now)),
      ],
      blockedPeriods: [
        for (final field in visible)
          ...await schedules.getBlockedPeriods(field.id, from: period.from, to: period.to),
      ],
    );
  }
}

sealed class StatisticsEvent extends Equatable {
  const StatisticsEvent();

  @override
  List<Object?> get props => [];
}

final class StatisticsStarted extends StatisticsEvent {
  const StatisticsStarted();
}

final class StatisticsPeriodKindChanged extends StatisticsEvent {
  final StatsPeriodKind kind;

  const StatisticsPeriodKindChanged(this.kind);

  @override
  List<Object?> get props => [kind];
}

final class StatisticsPeriodMoved extends StatisticsEvent {
  final int steps;

  const StatisticsPeriodMoved(this.steps);

  @override
  List<Object?> get props => [steps];
}

sealed class StatisticsState extends Equatable {
  final StatsPeriod period;

  const StatisticsState(this.period);

  @override
  List<Object?> get props => [period.kind, period.from];
}

final class StatisticsLoading extends StatisticsState {
  const StatisticsLoading(super.period);
}

final class StatisticsError extends StatisticsState {
  final String message;

  const StatisticsError(super.period, this.message);

  @override
  List<Object?> get props => [...super.props, message];
}

final class StatisticsLoaded extends StatisticsState {
  final OccupancyReport report;

  const StatisticsLoaded(super.period, this.report);

  bool get isEmpty => report.fields.isEmpty;

  @override
  List<Object?> get props => [
    ...super.props,
    [for (final f in report.fields) (f.fieldId, f.availableMinutes, f.bookedMinutes, f.completedCount, f.cancelledCount)],
  ];
}

final class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  final StatisticsRepository repository;
  final AppUser viewer;

  var _request = 0;

  StatisticsBloc({required this.repository, required this.viewer, DateTime Function()? clock})
    : super(StatisticsLoading(StatsPeriod.weekOf((clock ?? DateTime.now)()))) {
    on<StatisticsStarted>((event, emit) => _load(emit, state.period));
    on<StatisticsPeriodKindChanged>(
      (event, emit) => _load(emit, StatsPeriod.of(event.kind, state.period.from)),
    );
    on<StatisticsPeriodMoved>((event, emit) => _load(emit, _moved(state.period, event.steps)));
  }

  StatsPeriod _moved(StatsPeriod period, int steps) => switch (period.kind) {
    StatsPeriodKind.week => StatsPeriod.weekOf(
      DateTime(period.from.year, period.from.month, period.from.day + 7 * steps),
    ),
    StatsPeriodKind.month => StatsPeriod.monthOf(DateTime(period.from.year, period.from.month + steps)),
  };

  Future<void> _load(Emitter<StatisticsState> emit, StatsPeriod period) async {
    final request = ++_request;
    emit(StatisticsLoading(period));
    try {
      final report = await repository.getOccupancy(period: period);
      if (request != _request) return;
      emit(StatisticsLoaded(period, report));
    } catch (error) {
      if (request != _request) return;
      emit(StatisticsError(period, describeError(error)));
    }
  }
}
