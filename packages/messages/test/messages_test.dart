import 'dart:convert';

import 'package:contract/contract.dart';
import 'package:domain/domain.dart';
import 'package:mapping/mapping.dart';
import 'package:messages/messages.dart';
import 'package:test/test.dart';

/// Greška onako kako stiže sa servera: kroz pravi JSON tekst.
ErrorDto fromServer(ErrorDto sent) => ErrorDto.fromJson(
  jsonDecode(jsonEncode(sent.toJson())) as Map<String, Object?>,
);

const rules = <ReservationValidationError>[
  InvalidTimeRange(),
  ReservationInPast(),
  CheckInNotAllowed(),
  CancellationDeadlineExpired(),
  InvalidReservationStatus(),
  InvalidReservationDuration(),
  OutsideWorkingHours(),
  FieldBlocked(),
  SlotAlreadyTaken(),
  FieldUnavailable(),
];

void main() {
  group('ista poruka bez obzira ko je pravilo proverio', () {
    test('lokalna provera, greška sa servera i izuzetak daju isti tekst', () {
      for (final rule in rules) {
        final local = validationMessage(rule);
        final server = errorMessage(fromServer(rule.toErrorDto()));

        expect(server, local, reason: rule.runtimeType.toString());
        expect(describeError(ReservationRuleViolation(rule)), local);
        expect(
          describeError(ServerRejectedException(fromServer(rule.toErrorDto()))),
          local,
        );
      }
    });

    test('tekstovi su isti kao oni koje je korisnik do sada viđao', () {
      expect(
        validationMessage(const InvalidTimeRange()),
        'Kraj termina mora biti posle početka.',
      );
      expect(
        validationMessage(const ReservationInPast()),
        'Termin rezervacije mora biti u budućnosti.',
      );
      expect(
        validationMessage(const CheckInNotAllowed()),
        'Dolazak je moguće potvrditi od 24 do 5 sati pre početka termina.',
      );
      expect(
        validationMessage(const CancellationDeadlineExpired()),
        'Rezervaciju nije moguće otkazati manje od 5 sati pre početka.',
      );
      expect(
        validationMessage(const InvalidReservationStatus()),
        'Trenutni status rezervacije ne dozvoljava ovu radnju.',
      );
      expect(
        validationMessage(const InvalidReservationDuration()),
        'Trajanje rezervacije mora biti pozitivno.',
      );
      expect(
        validationMessage(const OutsideWorkingHours()),
        'Termin je van radnog vremena terena.',
      );
      expect(
        validationMessage(const FieldBlocked()),
        'Teren je blokiran u izabranom terminu.',
      );
      expect(
        validationMessage(const SlotAlreadyTaken()),
        'Termin se preklapa sa postojećom rezervacijom.',
      );
      expect(
        validationMessage(const FieldUnavailable()),
        'Teren trenutno nije dostupan za rezervisanje.',
      );
    });
  });

  group('podaci pravila dolaze sa servera', () {
    test('granica otkazivanja se čita iz greške, ne iz aplikacije', () {
      const sent = ErrorDto(
        code: ErrorCodes.cancellationDeadlineExpired,
        details: {ErrorDetailKeys.hours: 2},
      );

      expect(
        errorMessage(fromServer(sent)),
        'Rezervaciju nije moguće otkazati manje od 2 sata pre početka.',
      );
    });

    test(
      'server koji promeni rok menja poruku bez nove verzije aplikacije',
      () {
        const sent = ErrorDto(
          code: ErrorCodes.cancellationDeadlineExpired,
          details: {ErrorDetailKeys.hours: 12},
        );

        expect(errorMessage(sent), contains('12 sati'));
      },
    );

    test('check-in nosi oba prozora sa servera', () {
      const sent = ErrorDto(
        code: ErrorCodes.checkInNotAllowed,
        details: {
          ErrorDetailKeys.opensHours: 48,
          ErrorDetailKeys.closesHours: 1,
        },
      );

      expect(
        errorMessage(sent),
        'Dolazak je moguće potvrditi od 48 do 1 sat pre početka termina.',
      );
    });

    test('poznat kod bez podataka daje poruku bez brojeva, ne izuzetak', () {
      expect(
        errorMessage(
          const ErrorDto(code: ErrorCodes.cancellationDeadlineExpired),
        ),
        'Rok za otkazivanje rezervacije je istekao.',
      );
      expect(
        errorMessage(const ErrorDto(code: ErrorCodes.checkInNotAllowed)),
        'Dolazak trenutno nije moguće potvrditi.',
      );
    });

    test('podaci pogrešnog tipa se ignorišu', () {
      const sent = ErrorDto(
        code: ErrorCodes.cancellationDeadlineExpired,
        details: {ErrorDetailKeys.hours: 'pet', 'x': 1},
      );

      expect(errorMessage(sent), 'Rok za otkazivanje rezervacije je istekao.');
    });
  });

  group('stara verzija aplikacije dobija novi kod', () {
    test(
      'nepoznat kod daje opštu poruku, bez izuzetka i bez koda u tekstu',
      () {
        final sent = fromServer(
          const ErrorDto(
            code: 'court_closed_for_holiday',
            details: {'day': '2026-12-25'},
          ),
        );

        expect(sent.isKnown, isFalse);
        expect(errorMessage(sent), genericErrorMessage);
        expect(errorMessage(sent), isNot(contains('court_closed')));
        expect(errorMessage(sent), isNot(contains('2026-12-25')));
      },
    );

    test('Bloc-u stiže poruka za korisnika i za nepoznat kod', () {
      final error = ServerRejectedException(
        const ErrorDto(code: 'court_closed_for_holiday'),
      );

      expect(describeError(error), genericErrorMessage);
    });

    test('nepoznat kod nije pravilo, pa se ne pretvara u pogrešno pravilo', () {
      const unknown = ErrorDto(code: 'court_closed_for_holiday');

      expect(unknown.toValidationError(), isNull);
    });
  });

  group('nikad tehnički tekst', () {
    test('poruka za svaki poznat kod je čitljiva rečenica', () {
      for (final code in ErrorCodes.all) {
        final message = errorMessage(ErrorDto(code: code));

        expect(message, isNotEmpty, reason: code);
        expect(message, isNot(contains('_')), reason: code);
        expect(
          message.toLowerCase(),
          isNot(contains('exception')),
          reason: code,
        );
        expect(message, isNot(contains('Bad state')), reason: code);
        expect(message, isNot(contains(code)), reason: code);
        expect(message, endsWith('.'), reason: code);
      }
    });

    test('podaci iz greške se ne prepisuju u poruku', () {
      const sent = ErrorDto(
        code: ErrorCodes.internal,
        details: {
          'message': 'SQLSTATE[42S02]: Base table not found',
          'stack': 'at x',
        },
      );

      expect(errorMessage(sent), genericErrorMessage);
    });

    test('neočekivan izuzetak daje opštu poruku, ne njegov tekst', () {
      expect(
        describeError(const FormatException('Unexpected character at 0')),
        genericErrorMessage,
      );
      expect(
        describeError(Exception('SocketException: connection refused')),
        genericErrorMessage,
      );
      expect(describeError(ArgumentError('x')), genericErrorMessage);
    });

    test('nema mreže daje poruku za korisnika', () {
      expect(
        describeError(const ServerUnreachableException()),
        serverUnreachableMessage,
      );
    });

    test('nepostojeći zapis se opisuje bez podataka o zapisu', () {
      expect(
        describeError(const EntityNotFound('Reservation', 7)),
        'Traženi zapis nije pronađen.',
      );
    });

    test('prijava: tokenExpired i invalidCredentials imaju svoje poruke', () {
      expect(
        errorMessage(const ErrorDto(code: ErrorCodes.tokenExpired)),
        sessionExpiredMessage,
      );
      expect(
        errorMessage(const ErrorDto(code: ErrorCodes.invalidCredentials)),
        'Pogrešan e-mail ili lozinka.',
      );
    });

    test('deaktiviran nalog ima svoju poruku', () {
      expect(
        errorMessage(const ErrorDto(code: ErrorCodes.accountDeactivated)),
        'Nalog je deaktiviran. Obratite se administratoru.',
      );
    });

    test('poruka demo repozitorijuma (StateError) ostaje čitljiva', () {
      expect(
        describeError(StateError('Server trenutno nije dostupan.')),
        'Server trenutno nije dostupan.',
      );
    });
  });

  group('prijava u pogrešnu aplikaciju', () {
    test('svaka aplikacija kaže za koga je', () {
      expect(
        signInNotAllowedMessage(ClientApp.backoffice),
        'Backoffice je za vlasnike i administratore sportskih objekata.',
      );
      expect(
        signInNotAllowedMessage(ClientApp.mobile),
        'Ova aplikacija je za korisnike. Osoblje se prijavljuje u backoffice.',
      );
    });

    test('prazna polja imaju poruku', () {
      expect(credentialsRequiredMessage, 'Unesite e-mail i lozinku.');
    });
  });

  group('istek prijave', () {
    test('prepoznaje token_expired i ništa drugo', () {
      expect(
        isSessionExpired(
          const ServerRejectedException(
            ErrorDto(code: ErrorCodes.tokenExpired),
          ),
        ),
        isTrue,
      );
      expect(
        isSessionExpired(
          const ServerRejectedException(
            ErrorDto(code: ErrorCodes.invalidToken),
          ),
        ),
        isFalse,
      );
      expect(isSessionExpired(const ServerUnreachableException()), isFalse);
      expect(isSessionExpired(StateError('x')), isFalse);
    });
  });

  group('sati na srpskom', () {
    test('jednina, dvojina i množina', () {
      expect(hoursLabel(1), '1 sat');
      expect(hoursLabel(2), '2 sata');
      expect(hoursLabel(4), '4 sata');
      expect(hoursLabel(5), '5 sati');
      expect(hoursLabel(11), '11 sati');
      expect(hoursLabel(12), '12 sati');
      expect(hoursLabel(14), '14 sati');
      expect(hoursLabel(21), '21 sat');
      expect(hoursLabel(22), '22 sata');
      expect(hoursLabel(24), '24 sata');
      expect(hoursLabel(25), '25 sati');
      expect(hoursLabel(101), '101 sat');
      expect(hoursLabel(111), '111 sati');
    });
  });

  group('blokade terena', () {
    test('poruka za svako pravilo je ista kao u domenu', () {
      for (final error in const <BlockedPeriodError>[
        InvalidBlockRange(),
        BlockInPast(),
        BlockOverlapsConfirmedReservation(),
      ]) {
        final server = errorMessage(fromServer(error.toErrorDto()));

        expect(server, error.message);
        expect(describeError(BlockedPeriodRuleViolation(error)), error.message);
        expect(
          describeError(
            ServerRejectedException(fromServer(error.toErrorDto())),
          ),
          error.message,
        );
      }
    });

    test('preklapanje sa rezervacijom kaže razlog', () {
      expect(
        errorMessage(const ErrorDto(code: ErrorCodes.blockOverlapsReservation)),
        'U izabranom periodu već postoji potvrđena rezervacija.',
      );
    });
  });
}
