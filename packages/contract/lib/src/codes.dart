// Stabilni tekstualni kodovi na mreži (odluka 5 u docs/kt2-decisions.md).
//
// DTO-ovi nose običan `String`, a ne enum: nepoznat kod (server je novije
// verzije od aplikacije) prolazi kroz ugovor neoštećen. Tek prevod u domen
// (paket `mapping`) odlučuje šta radi sa nepoznatim kodom, pa aplikacija ne pada.
// Stanje se ne kodira indeksom enuma jer bi promena redosleda tiho promenila značenje.

abstract final class ReservationStatusCodes {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

abstract final class PaymentStatusCodes {
  static const unpaid = 'unpaid';
  static const paid = 'paid';
}

abstract final class RoleCodes {
  static const user = 'user';
  static const owner = 'owner';
  static const admin = 'admin';
}

abstract final class SportCodes {
  static const football = 'football';
  static const basketball = 'basketball';
  static const tennis = 'tennis';
  static const padel = 'padel';
  static const volleyball = 'volleyball';
  static const swimming = 'swimming';
  static const futsal = 'futsal';
  static const other = 'other';
}

abstract final class ConfirmationModeCodes {
  static const automatic = 'automatic';
  static const manual = 'manual';
}

abstract final class ApprovalStatusCodes {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

abstract final class WeekDayCodes {
  static const monday = 'monday';
  static const tuesday = 'tuesday';
  static const wednesday = 'wednesday';
  static const thursday = 'thursday';
  static const friday = 'friday';
  static const saturday = 'saturday';
  static const sunday = 'sunday';
}

/// Stanje jednog termina u odgovoru o dostupnosti.
abstract final class SlotStateCodes {
  static const free = 'free';
  static const taken = 'taken';
  static const blocked = 'blocked';
  static const past = 'past';
}

abstract final class StatsPeriodCodes {
  static const week = 'week';
  static const month = 'month';
}
