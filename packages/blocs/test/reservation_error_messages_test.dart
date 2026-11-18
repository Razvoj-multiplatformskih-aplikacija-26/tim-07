import 'package:blocs/blocs.dart';
import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

/// Repozitorijum koji uvek odbija poziv zadatom greškom, kao što bi uradio
/// HTTP repozitorijum kada server odbije zahtev ili nema mreže.
final class _RejectingRepository implements ReservationRepository {
  final Object error;

  const _RejectingRepository(this.error);

  @override
  Future<List<Reservation>> getReservations() async => throw error;

  @override
  Future<List<Reservation>> getReservationsByUser(UserId userId) async =>
      throw error;

  @override
  Future<List<Reservation>> getReservationsByField(FieldId fieldId) async =>
      throw error;

  @override
  Future<Reservation?> getReservationById(ReservationId id) async =>
      throw error;

  @override
  Future<Reservation> createReservation({
    required FieldId fieldId,
    required UserId userId,
    required DateTime startTime,
    required DateTime endTime,
  }) async => throw error;

  @override
  Future<Reservation> updateReservationStatus({
    required ReservationId reservationId,
    required ReservationStatus status,
  }) async => throw error;

  @override
  Future<Reservation> checkIn(ReservationId reservationId) async => throw error;

  @override
  Future<Reservation> cancelReservation(ReservationId reservationId) async =>
      throw error;
}

/// Poruka koju korisnik vidi kada učitavanje rezervacija padne sa [error].
Future<String> messageFor(Object error) async {
  final bloc = ReservationBloc(repository: _RejectingRepository(error));
  bloc.add(const ReservationsRequested());

  final state = await bloc.stream.firstWhere((s) => s is ReservationError);
  await bloc.close();

  return (state as ReservationError).message;
}

void main() {
  late DateTime now;
  late FakeReservationRepository repository;

  setUp(() {
    now = DateTime(2026, 10, 17, 12);
    repository = FakeReservationRepository(
      fields: DemoData.fields,
      schedules: DemoData.schedules,
      reservations: DemoData.createReservations(now: now),
      blockedPeriods: DemoData.blockedPeriods,
      clock: () => now,
    );
  });

  group('poruka greške u stanju Bloc-a', () {
    test('preklapanje koje odbije repozitorijum ima istu poruku kao lokalna provera', () async {
      final bloc = ReservationBloc(repository: repository);
      bloc.add(
        ReservationCreateRequested(
          fieldId: FieldId(1),
          userId: UserId(3),
          startTime: DateTime(2026, 10, 18, 19),
          endTime: DateTime(2026, 10, 18, 21),
        ),
      );

      final state = await bloc.stream.firstWhere((s) => s is ReservationError);
      await bloc.close();

      expect(
        (state as ReservationError).message,
        validationMessage(const SlotAlreadyTaken()),
      );
      expect(state.message, isNot(contains('Bad state')));
    });

    test('isto pravilo koje odbije server daje istu poruku', () async {
      final fromRepository = await messageFor(
        const ReservationRuleViolation(SlotAlreadyTaken()),
      );
      final fromServer = await messageFor(
        ServerRejectedException(const SlotAlreadyTaken().toErrorDto()),
      );

      expect(fromServer, fromRepository);
      expect(fromServer, 'Termin se preklapa sa postojećom rezervacijom.');
    });

    test('rok otkazivanja nosi broj sati koji je poslao server', () async {
      final message = await messageFor(
        const ServerRejectedException(
          ErrorDto(
            code: ErrorCodes.cancellationDeadlineExpired,
            details: {ErrorDetailKeys.hours: 5},
          ),
        ),
      );

      expect(
        message,
        'Rezervaciju nije moguće otkazati manje od 5 sati pre početka.',
      );
    });

    test('rezervacija koja se ne može otkazati ima poruku pravila', () async {
      // Rezervacija počinje za manje od 5 sati, pa se bez potvrde sama otkazuje,
      // a otkazana rezervacija je konačno stanje.
      final late = await repository.createReservation(
        fieldId: FieldId(1),
        userId: UserId(3),
        startTime: now.add(const Duration(hours: 3)),
        endTime: now.add(const Duration(hours: 4)),
      );

      final bloc = ReservationBloc(repository: repository);
      bloc.add(ReservationCancelRequested(late.id));

      final state = await bloc.stream.firstWhere((s) => s is ReservationError);
      await bloc.close();

      expect(
        (state as ReservationError).message,
        validationMessage(const InvalidReservationStatus()),
      );
    });

    test(
      'stara verzija aplikacije: nepoznat kod daje opštu poruku, Bloc ne pada',
      () async {
        final message = await messageFor(
          const ServerRejectedException(
            ErrorDto(code: 'court_closed_for_holiday'),
          ),
        );

        expect(message, genericErrorMessage);
      },
    );

    test('nema mreže', () async {
      expect(
        await messageFor(const ServerUnreachableException()),
        serverUnreachableMessage,
      );
    });

    test('neočekivan izuzetak ne prikazuje tehnički tekst', () async {
      final message = await messageFor(
        const FormatException('Unexpected character (at line 1)'),
      );

      expect(message, genericErrorMessage);
      expect(message, isNot(contains('FormatException')));
    });

    test(
      'poruka demo greške iz lažnog repozitorijuma ostaje čitljiva',
      () async {
        repository.simulateError = true;

        final bloc = ReservationBloc(repository: repository);
        bloc.add(const ReservationsRequested());

        final state = await bloc.stream.firstWhere(
          (s) => s is ReservationError,
        );
        await bloc.close();

        expect(
          (state as ReservationError).message,
          'Simulirana greska pri ucitavanju rezervacija.',
        );
      },
    );
  });
}
