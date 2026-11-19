import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';

/// Greška spremna za slanje: kod i podaci pravila, a HTTP status sledi iz koda.
///
/// Server pravi poruku za korisnika nikada, samo kod i podatke. Poruku pravi
/// klijent iz koda, istom funkcijom kao kada pravilo proveri lokalno (T42).
final class ApiFailure {
  final ErrorDto error;

  const ApiFailure(this.error);

  int get status => httpStatusFor(error.code);
}

extension ValidationErrorMapping on ReservationValidationError {
  /// Kod i podaci pravila. Rokovi dolaze iz domena (`Reservation`), da se
  /// poruka klijenta ne razilazi sa pravilom koje je server primenio.
  ErrorDto toErrorDto() => switch (this) {
    InvalidTimeRange() => const ErrorDto(code: ErrorCodes.invalidTimeRange),
    ReservationInPast() => const ErrorDto(code: ErrorCodes.reservationInPast),
    CheckInNotAllowed() => const ErrorDto(
      code: ErrorCodes.checkInNotAllowed,
      details: {
        ErrorDetailKeys.opensHours: Reservation.checkInOpensHoursBefore,
        ErrorDetailKeys.closesHours: Reservation.checkInClosesHoursBefore,
      },
    ),
    CancellationDeadlineExpired() => const ErrorDto(
      code: ErrorCodes.cancellationDeadlineExpired,
      details: {ErrorDetailKeys.hours: Reservation.checkInClosesHoursBefore},
    ),
    InvalidReservationStatus() => const ErrorDto(
      code: ErrorCodes.invalidStatusTransition,
    ),
    InvalidReservationDuration() => const ErrorDto(
      code: ErrorCodes.invalidDuration,
    ),
    OutsideWorkingHours() => const ErrorDto(
      code: ErrorCodes.outsideWorkingHours,
    ),
    FieldBlocked() => const ErrorDto(code: ErrorCodes.fieldBlocked),
    SlotAlreadyTaken() => const ErrorDto(code: ErrorCodes.slotTaken),
    FieldUnavailable() => const ErrorDto(code: ErrorCodes.fieldUnavailable),
  };

  ApiFailure toFailure() => ApiFailure(toErrorDto());
}

extension ErrorDtoMapping on ErrorDto {
  /// Pravilo iz domena za ovaj kod, ili `null` kada kod nije pravilo
  /// (prijava, prava, `not_found`) ili ga ova verzija aplikacije ne poznaje.
  ///
  /// `null` za nepoznat kod je namerno: klijent tada prikazuje opštu poruku
  /// umesto da padne (aplikacija starija od servera).
  ReservationValidationError? toValidationError() => switch (code) {
    ErrorCodes.invalidTimeRange => const InvalidTimeRange(),
    ErrorCodes.reservationInPast => const ReservationInPast(),
    ErrorCodes.checkInNotAllowed => const CheckInNotAllowed(),
    ErrorCodes.cancellationDeadlineExpired =>
      const CancellationDeadlineExpired(),
    ErrorCodes.invalidStatusTransition => const InvalidReservationStatus(),
    ErrorCodes.invalidDuration => const InvalidReservationDuration(),
    ErrorCodes.outsideWorkingHours => const OutsideWorkingHours(),
    ErrorCodes.fieldBlocked => const FieldBlocked(),
    ErrorCodes.slotTaken => const SlotAlreadyTaken(),
    ErrorCodes.fieldUnavailable => const FieldUnavailable(),
    _ => null,
  };
}

extension BlockedPeriodErrorMapping on BlockedPeriodError {
  /// Kod greške blokade terena; bez podataka, poruku pravi klijent.
  ErrorDto toErrorDto() => switch (this) {
    InvalidBlockRange() => const ErrorDto(code: ErrorCodes.invalidBlockRange),
    BlockInPast() => const ErrorDto(code: ErrorCodes.blockInPast),
    BlockOverlapsConfirmedReservation() => const ErrorDto(
      code: ErrorCodes.blockOverlapsReservation,
    ),
  };

  ApiFailure toFailure() => ApiFailure(toErrorDto());
}

extension BlockedPeriodErrorDtoMapping on ErrorDto {
  /// Pravilo blokade za ovaj kod, ili `null` kada kod nije pravilo blokade.
  BlockedPeriodError? toBlockedPeriodError() => switch (code) {
    ErrorCodes.invalidBlockRange => const InvalidBlockRange(),
    ErrorCodes.blockInPast => const BlockInPast(),
    ErrorCodes.blockOverlapsReservation =>
      const BlockOverlapsConfirmedReservation(),
    _ => null,
  };
}

/// Prevodi izuzetak domena u grešku za mrežu, ili vraća `null` kada izuzetak
/// nije greška domena (tada je to `internal`, a detalji ostaju u logu servera).
ApiFailure? failureOf(Object error) => switch (error) {
  ReservationRuleViolation(:final error) => error.toFailure(),
  BlockedPeriodRuleViolation(:final error) => error.toFailure(),
  // Ne otkriva da li zapis postoji kod nekog drugog (odluka 4): isto kao tuđ zapis.
  EntityNotFound() => const ApiFailure(ErrorDto(code: ErrorCodes.notFound)),
  ApprovalTransitionNotAllowed(:final from, :final to) => ApiFailure(
    ErrorDto(
      code: ErrorCodes.invalidApprovalTransition,
      details: {
        ErrorDetailKeys.from: approvalStatusToCode(from),
        ErrorDetailKeys.to: approvalStatusToCode(to),
      },
    ),
  ),
  _ => null,
};
