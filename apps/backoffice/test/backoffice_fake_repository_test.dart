import 'package:backoffice/data/backoffice_repository.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Vraca demo rezervacije', () async {
    final repository = createBackofficeRepository(delay: Duration.zero);

    expect(await repository.getReservations(), hasLength(7));
  });

  test('Greska vazi samo za sledeci zahtev', () async {
    final repository = createBackofficeRepository(delay: Duration.zero);

    repository.failNextRequest();
    expect(repository.failsNextRequest, isTrue);

    await expectLater(repository.getReservations(), throwsStateError);
    expect(repository.failsNextRequest, isFalse);
    expect(await repository.getReservations(), hasLength(7));
  });

  test('Greska vazi i za akcije, ne samo za ucitavanje', () async {
    final repository = createBackofficeRepository(delay: Duration.zero);

    repository.failNextRequest();

    await expectLater(
      repository.updateReservationStatus(
        reservationId: const ReservationId(2),
        status: ReservationStatus.confirmed,
      ),
      throwsStateError,
    );
    final reservation =
        await repository.getReservationById(const ReservationId(2));
    expect(reservation?.status, ReservationStatus.pending);
  });

  test('Prazan odgovor vazi samo za sledece ucitavanje', () async {
    final repository = createBackofficeRepository(delay: Duration.zero);

    repository.returnEmptyOnNextRequest();

    expect(await repository.getReservations(), isEmpty);
    expect(await repository.getReservations(), hasLength(7));
  });

  test('Odgovor stize posle kasnjenja', () async {
    final repository = createBackofficeRepository(
      delay: const Duration(milliseconds: 50),
    );
    final watch = Stopwatch()..start();

    await repository.getReservations();

    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(45));
  });
}
