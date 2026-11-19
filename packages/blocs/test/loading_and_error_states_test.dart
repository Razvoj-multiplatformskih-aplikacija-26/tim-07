import 'dart:async';

import 'package:blocs/blocs.dart';
import 'package:domain/domain.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

/// Spisak terena koji se ponaša kako test kaže: odgovara tek kada se pusti
/// ([gate]) ili ne radi ([error]). Samo ono što Bloc-ovi zovu je napisano;
/// ostalo baca grešku, što bi test odmah otkrio.
final class _Fields implements SportsFieldRepository {
  Object? error;
  Completer<void>? gate;
  List<SportsField> fields = const [];

  Future<T> _answer<T>(T Function() result) async {
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    return result();
  }

  @override
  Future<SportsField?> getFieldById(FieldId id) =>
      _answer(() => fields.where((field) => field.id == id).firstOrNull);

  @override
  Future<List<SportsField>> getFieldsAwaitingApproval() =>
      _answer(() => fields);

  @override
  Future<List<SportsField>> getFieldsByOwner(UserId ownerId) => _answer(
    () => [
      for (final field in fields)
        if (field.ownerId == ownerId) field,
    ],
  );

  @override
  Future<List<SportsField>> getFields() => _answer(() => fields);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Statistika koja ne može da se izračuna.
final class _Statistics implements StatisticsRepository {
  Object? error;

  @override
  Future<OccupancyReport> getOccupancy({
    required StatsPeriod period,
    UserId? ownerId,
  }) async {
    final failure = error;
    if (failure != null) throw failure;
    return OccupancyReport(period: period, fields: const []);
  }
}

AppUser person(int id, UserRole role) => AppUser(
  id: UserId(id),
  firstName: 'Ime',
  lastName: role.name,
  email: '${role.name}@terenzo.rs',
  phoneNumber: '060',
  dateOfBirth: DateTime(1990),
  role: role,
  createdAt: DateTime(2026),
);

SportsField field(int id, {int owner = 10}) => SportsField(
  id: FieldId(id),
  ownerId: UserId(owner),
  name: 'Teren $id',
  description: 'Opis',
  sport: SportType.tennis,
  address: 'Ulica 1',
  city: 'Beograd',
  pricePerHour: 2000,
  contactPhone: '060',
  confirmationMode: ConfirmationMode.manual,
);

final unreachable = describeError(const ServerUnreachableException());

void main() {
  group('StatisticsBloc: učitavanje i greška', () {
    final now = DateTime(2030, 6, 5);
    final owner = person(10, UserRole.owner);

    test('počinje učitavanjem tekuće nedelje', () async {
      final bloc = StatisticsBloc(
        repository: _Statistics(),
        viewer: owner,
        clock: () => now,
      );
      addTearDown(bloc.close);

      expect(bloc.state, isA<StatisticsLoading>());
      expect(bloc.state.period.from, DateTime(2030, 6, 3));
    });

    test(
      'greška izvora je stanje greške sa porukom i istim periodom',
      () async {
        final source = _Statistics()
          ..error = const ServerUnreachableException();
        final bloc = StatisticsBloc(
          repository: source,
          viewer: owner,
          clock: () => now,
        );
        addTearDown(bloc.close);

        bloc.add(const StatisticsStarted());
        final state = await bloc.stream.firstWhere(
          (s) => s is! StatisticsLoading,
        );

        expect(state, isA<StatisticsError>());
        expect((state as StatisticsError).message, unreachable);
        expect(state.period.from, DateTime(2030, 6, 3));
      },
    );

    test('posle greške ponovni pokušaj učitava izveštaj', () async {
      final source = _Statistics()..error = const ServerUnreachableException();
      final bloc = StatisticsBloc(
        repository: source,
        viewer: owner,
        clock: () => now,
      );
      addTearDown(bloc.close);
      bloc.add(const StatisticsStarted());
      await bloc.stream.firstWhere((s) => s is StatisticsError);

      source.error = null;
      bloc.add(const StatisticsStarted());

      expect(
        await bloc.stream.firstWhere((s) => s is StatisticsLoaded),
        isA<StatisticsLoaded>(),
      );
    });
  });

  group('FieldReviewBloc: učitavanje i greška', () {
    final admin = person(1, UserRole.admin);

    test('počinje učitavanjem, pa prikazuje terene na čekanju', () async {
      final source = _Fields()
        ..gate = Completer<void>()
        ..fields = [field(5)];
      final bloc = FieldReviewBloc(fields: source, reviewer: admin);
      addTearDown(bloc.close);
      expect(bloc.state, isA<FieldReviewLoading>());

      bloc.add(const FieldReviewStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<FieldReviewLoading>());

      source.gate!.complete();
      final state = await bloc.stream.firstWhere((s) => s is FieldReviewLoaded);

      expect((state as FieldReviewLoaded).waiting, hasLength(1));
    });

    test('greška izvora je stanje greške sa porukom', () async {
      final source = _Fields()..error = const ServerUnreachableException();
      final bloc = FieldReviewBloc(fields: source, reviewer: admin);
      addTearDown(bloc.close);

      bloc.add(const FieldReviewStarted());
      final state = await bloc.stream.firstWhere((s) => s is FieldReviewError);

      expect((state as FieldReviewError).message, unreachable);
    });

    test('posle greške ponovni pokušaj učitava terene', () async {
      final source = _Fields()..error = const ServerUnreachableException();
      final bloc = FieldReviewBloc(fields: source, reviewer: admin);
      addTearDown(bloc.close);
      bloc.add(const FieldReviewStarted());
      await bloc.stream.firstWhere((s) => s is FieldReviewError);

      source.error = null;
      bloc.add(const FieldReviewStarted());

      expect(
        await bloc.stream.firstWhere((s) => s is FieldReviewLoaded),
        isA<FieldReviewLoaded>(),
      );
    });
  });

  group('FieldManagementBloc: greška', () {
    final owner = person(10, UserRole.owner);

    test('greška pri učitavanju terena vlasnika je stanje greške', () async {
      final source = _Fields()..error = const ServerUnreachableException();
      final bloc = FieldManagementBloc(
        fields: source,
        schedules: FakeFieldScheduleRepository(),
        owner: owner,
      );
      addTearDown(bloc.close);
      expect(bloc.state, isA<FieldManagementLoading>());

      bloc.add(const FieldManagementStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s is FieldManagementError,
      );

      expect((state as FieldManagementError).message, unreachable);
    });

    test('posle greške ponovni pokušaj učitava terene', () async {
      final source = _Fields()
        ..error = const ServerUnreachableException()
        ..fields = [field(1)];
      final bloc = FieldManagementBloc(
        fields: source,
        schedules: FakeFieldScheduleRepository(),
        owner: owner,
      );
      addTearDown(bloc.close);
      bloc.add(const FieldManagementStarted());
      await bloc.stream.firstWhere((s) => s is FieldManagementError);

      source.error = null;
      bloc.add(const FieldManagementStarted());

      expect(
        await bloc.stream.firstWhere((s) => s is FieldManagementLoaded),
        isA<FieldManagementLoaded>(),
      );
    });
  });

  group('FieldDetailsBloc: učitavanje', () {
    test('dok server odgovara, stanje je učitavanje, pa teren', () async {
      final source = _Fields()
        ..gate = Completer<void>()
        ..fields = [field(3)];
      final bloc = FieldDetailsBloc(repository: source);
      addTearDown(bloc.close);

      bloc.add(const FieldDetailsRequested(FieldId(3)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<FieldDetailsLoading>());

      source.gate!.complete();
      final state = await bloc.stream.firstWhere(
        (s) => s is! FieldDetailsLoading,
      );

      expect(state, isA<FieldDetailsLoaded>());
    });

    test('ponovni zahtev posle greške opet prolazi kroz učitavanje', () async {
      final source = _Fields()
        ..error = const ServerUnreachableException()
        ..fields = [field(3)];
      final bloc = FieldDetailsBloc(repository: source);
      addTearDown(bloc.close);
      bloc.add(const FieldDetailsRequested(FieldId(3)));
      await bloc.stream.firstWhere((s) => s is FieldDetailsError);

      source.error = null;
      source.gate = Completer<void>();
      bloc.add(const FieldDetailsRequested(FieldId(3)));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<FieldDetailsLoading>());

      source.gate!.complete();
      expect(
        await bloc.stream.firstWhere((s) => s is FieldDetailsLoaded),
        isA<FieldDetailsLoaded>(),
      );
    });
  });
}
