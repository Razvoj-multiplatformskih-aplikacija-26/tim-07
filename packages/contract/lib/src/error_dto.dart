import 'json.dart';

/// Kodovi grešaka na mreži (odluka 13 u docs/kt2-decisions.md).
///
/// Server nikad ne šalje poruku za korisnika, samo kod i podatke pravila.
/// Poruku na srpskom pravi klijent iz koda, istom funkcijom kao kada pravilo
/// proveri lokalno, pa korisnik vidi istu poruku bez obzira ko je pravilo proverio.
abstract final class ErrorCodes {
  // 400
  static const badRequest = 'bad_request';
  static const payloadTooLarge = 'payload_too_large';

  // 401
  static const unauthenticated = 'unauthenticated';
  static const invalidToken = 'invalid_token';
  static const tokenExpired = 'token_expired';
  static const invalidCredentials = 'invalid_credentials';

  // 403 (nalog je deaktiviran)
  static const accountDeactivated = 'account_deactivated';

  // 403, 404
  static const forbidden = 'forbidden';
  static const notFound = 'not_found';

  // 409
  static const slotTaken = 'slot_taken';
  static const invalidStatusTransition = 'invalid_status_transition';
  static const invalidApprovalTransition = 'invalid_approval_transition';

  // 409 (blokada terena preko potvrđene rezervacije)
  static const blockOverlapsReservation = 'block_overlaps_reservation';

  // 422 (pravila iz domena)
  static const invalidBlockRange = 'invalid_block_range';
  static const blockInPast = 'block_in_past';
  static const invalidTimeRange = 'invalid_time_range';
  static const reservationInPast = 'reservation_in_past';
  static const outsideWorkingHours = 'outside_working_hours';
  static const fieldBlocked = 'field_blocked';
  static const fieldUnavailable = 'field_unavailable';
  static const cancellationDeadlineExpired = 'cancellation_deadline_expired';
  static const checkInNotAllowed = 'check_in_not_allowed';
  static const invalidDuration = 'invalid_duration';

  // 500
  static const internal = 'internal';

  /// Svi kodovi koje ova verzija ugovora poznaje.
  static const all = <String>[
    badRequest,
    payloadTooLarge,
    unauthenticated,
    invalidToken,
    tokenExpired,
    invalidCredentials,
    accountDeactivated,
    forbidden,
    notFound,
    slotTaken,
    invalidStatusTransition,
    invalidApprovalTransition,
    blockOverlapsReservation,
    invalidBlockRange,
    blockInPast,
    invalidTimeRange,
    reservationInPast,
    outsideWorkingHours,
    fieldBlocked,
    fieldUnavailable,
    cancellationDeadlineExpired,
    checkInNotAllowed,
    invalidDuration,
    internal,
  ];
}

/// HTTP status za kod greške (tabela u odluci 13). Nepoznat kod je 500.
///
/// Na jednom mestu da server i klijent ne drže svaki svoju tabelu.
int httpStatusFor(String code) => switch (code) {
  ErrorCodes.badRequest => 400,
  ErrorCodes.payloadTooLarge => 413,
  ErrorCodes.unauthenticated ||
  ErrorCodes.invalidToken ||
  ErrorCodes.tokenExpired ||
  ErrorCodes.invalidCredentials => 401,
  ErrorCodes.forbidden || ErrorCodes.accountDeactivated => 403,
  ErrorCodes.notFound => 404,
  ErrorCodes.slotTaken ||
  ErrorCodes.invalidStatusTransition ||
  ErrorCodes.invalidApprovalTransition ||
  ErrorCodes.blockOverlapsReservation => 409,
  ErrorCodes.invalidBlockRange ||
  ErrorCodes.blockInPast ||
  ErrorCodes.invalidTimeRange ||
  ErrorCodes.reservationInPast ||
  ErrorCodes.outsideWorkingHours ||
  ErrorCodes.fieldBlocked ||
  ErrorCodes.fieldUnavailable ||
  ErrorCodes.cancellationDeadlineExpired ||
  ErrorCodes.checkInNotAllowed ||
  ErrorCodes.invalidDuration => 422,
  _ => 500,
};

/// Imena podataka koje greška može da nosi u `details`.
abstract final class ErrorDetailKeys {
  /// `cancellation_deadline_expired`: koliko sati pre početka je rok.
  static const hours = 'hours';

  /// `check_in_not_allowed`: koliko sati pre početka se check-in otvara i zatvara.
  static const opensHours = 'opensHours';
  static const closesHours = 'closesHours';

  /// `bad_request`: ime polja ili razlog.
  static const fields = 'fields';
  static const reason = 'reason';

  /// `invalid_approval_transition`: stanje odobrenosti pre i posle.
  static const from = 'from';
  static const to = 'to';
}

/// Greška koju server vraća: `{"error": {"code": "...", "details": {...}}}`.
final class ErrorDto {
  final String code;
  final Map<String, Object?> details;

  const ErrorDto({required this.code, this.details = const {}});

  /// Nepoznat kod nije izuzetak: klijent ga prikazuje kao opštu grešku.
  bool get isKnown => _known.contains(code);

  int? detailInt(String key) => switch (details[key]) {
    final int value => value,
    _ => null,
  };

  Map<String, Object?> toJson() => {
    'error': {'code': code, 'details': details},
  };

  /// Čita telo odgovora. Baca `FormatException` samo kada telo uopšte nije
  /// u obliku greške (npr. HTML sa proxy-ja), da klijent to prikaže kao grešku mreže.
  factory ErrorDto.fromJson(Map<String, Object?> json) {
    final error = jsonObject(json['error']);
    final rawDetails = error['details'];
    return ErrorDto(
      code: jsonString(error, 'code'),
      details: rawDetails is Map<String, Object?> ? rawDetails : const {},
    );
  }

  static final Set<String> _known = ErrorCodes.all.toSet();
}
