/// Adrese servera na jednom mestu: koriste ih i klijenti i server.
abstract final class ApiPaths {
  static const health = '/health';

  // Prijava.
  static const login = '/auth/login';
  static const me = '/auth/me';

  // Javni katalog (bez prijave, odluka 8).
  static const fields = '/fields';
  static const sports = '/sports';

  static String field(int id) => '$fields/$id';

  static String availability(int fieldId) => '${field(fieldId)}/availability';

  // Radno vreme i blokirani periodi terena.
  static String schedule(int fieldId) => '${field(fieldId)}/schedule';

  static String blockedPeriods(int fieldId) =>
      '${field(fieldId)}/blocked-periods';

  /// Administrator odobrava ili odbija objavljivanje terena.
  static String fieldReview(int fieldId) => '${field(fieldId)}/review';

  /// Tereni koji čekaju odobrenje (samo administrator).
  static const fieldsAwaitingApproval = '/fields/awaiting-approval';

  // Rezervacije (traže prijavu).
  static const reservations = '/reservations';

  static String reservation(int id) => '$reservations/$id';

  static String confirmReservation(int id) => '${reservation(id)}/confirm';

  static String rejectReservation(int id) => '${reservation(id)}/reject';

  static String cancelReservation(int id) => '${reservation(id)}/cancel';

  static String checkInReservation(int id) => '${reservation(id)}/check-in';

  // Statistika i nalozi.
  static const stats = '/stats/occupancy';
  static const users = '/users';
}

/// Imena parametara upita.
abstract final class ApiQuery {
  static const limit = 'limit';
  static const offset = 'offset';
  static const sport = 'sport';
  static const city = 'city';
  static const search = 'search';
  static const date = 'date';
  static const status = 'status';
  static const fieldId = 'fieldId';
  static const from = 'from';
  static const to = 'to';
  static const period = 'period';
  static const day = 'day';
  static const role = 'role';
}

/// Straničenje (odluka 6): podrazumevano 20, najviše 100.
abstract final class ApiPaging {
  static const defaultLimit = 20;
  static const maxLimit = 100;
}

abstract final class ApiHeaders {
  static const authorization = 'authorization';

  static String bearer(String token) => 'Bearer $token';
}
