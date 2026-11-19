import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

/// Kod sa mreže koji ova verzija domena ne poznaje (npr. server je noviji od
/// aplikacije). Ne sme da obori aplikaciju: pozivalac ga hvata i prikazuje
/// opštu poruku, ili preskače taj zapis (`toDomainOrNull`).
final class UnknownCodeException implements Exception {
  /// Vrsta koda: `reservationStatus`, `sport`, `role`, ...
  final String kind;
  final String code;

  const UnknownCodeException(this.kind, this.code);

  @override
  String toString() => 'Nepoznat kod "$code" za $kind.';
}

// Kodovi na mreži se ne uzimaju iz `enum.name`: preimenovanje vrednosti u
// domenu ne sme tiho da promeni ugovor. Zato je svaki kod ispisan ovde.

String reservationStatusToCode(ReservationStatus value) => switch (value) {
  ReservationStatus.pending => ReservationStatusCodes.pending,
  ReservationStatus.confirmed => ReservationStatusCodes.confirmed,
  ReservationStatus.completed => ReservationStatusCodes.completed,
  ReservationStatus.cancelled => ReservationStatusCodes.cancelled,
};

ReservationStatus? reservationStatusFromCode(String code) => switch (code) {
  ReservationStatusCodes.pending => ReservationStatus.pending,
  ReservationStatusCodes.confirmed => ReservationStatus.confirmed,
  ReservationStatusCodes.completed => ReservationStatus.completed,
  ReservationStatusCodes.cancelled => ReservationStatus.cancelled,
  _ => null,
};

String paymentStatusToCode(PaymentStatus value) => switch (value) {
  PaymentStatus.unpaid => PaymentStatusCodes.unpaid,
  PaymentStatus.paid => PaymentStatusCodes.paid,
};

PaymentStatus? paymentStatusFromCode(String code) => switch (code) {
  PaymentStatusCodes.unpaid => PaymentStatus.unpaid,
  PaymentStatusCodes.paid => PaymentStatus.paid,
  _ => null,
};

String roleToCode(UserRole value) => switch (value) {
  UserRole.user => RoleCodes.user,
  UserRole.owner => RoleCodes.owner,
  UserRole.admin => RoleCodes.admin,
};

UserRole? roleFromCode(String code) => switch (code) {
  RoleCodes.user => UserRole.user,
  RoleCodes.owner => UserRole.owner,
  RoleCodes.admin => UserRole.admin,
  _ => null,
};

String sportToCode(SportType value) => switch (value) {
  SportType.football => SportCodes.football,
  SportType.basketball => SportCodes.basketball,
  SportType.tennis => SportCodes.tennis,
  SportType.padel => SportCodes.padel,
  SportType.volleyball => SportCodes.volleyball,
  SportType.swimming => SportCodes.swimming,
  SportType.futsal => SportCodes.futsal,
  SportType.other => SportCodes.other,
};

SportType? sportFromCode(String code) => switch (code) {
  SportCodes.football => SportType.football,
  SportCodes.basketball => SportType.basketball,
  SportCodes.tennis => SportType.tennis,
  SportCodes.padel => SportType.padel,
  SportCodes.volleyball => SportType.volleyball,
  SportCodes.swimming => SportType.swimming,
  SportCodes.futsal => SportType.futsal,
  SportCodes.other => SportType.other,
  _ => null,
};

String confirmationModeToCode(ConfirmationMode value) => switch (value) {
  ConfirmationMode.automatic => ConfirmationModeCodes.automatic,
  ConfirmationMode.manual => ConfirmationModeCodes.manual,
};

ConfirmationMode? confirmationModeFromCode(String code) => switch (code) {
  ConfirmationModeCodes.automatic => ConfirmationMode.automatic,
  ConfirmationModeCodes.manual => ConfirmationMode.manual,
  _ => null,
};

String approvalStatusToCode(ApprovalStatus value) => switch (value) {
  ApprovalStatus.pending => ApprovalStatusCodes.pending,
  ApprovalStatus.approved => ApprovalStatusCodes.approved,
  ApprovalStatus.rejected => ApprovalStatusCodes.rejected,
};

ApprovalStatus? approvalStatusFromCode(String code) => switch (code) {
  ApprovalStatusCodes.pending => ApprovalStatus.pending,
  ApprovalStatusCodes.approved => ApprovalStatus.approved,
  ApprovalStatusCodes.rejected => ApprovalStatus.rejected,
  _ => null,
};

String weekDayToCode(WeekDay value) => switch (value) {
  WeekDay.monday => WeekDayCodes.monday,
  WeekDay.tuesday => WeekDayCodes.tuesday,
  WeekDay.wednesday => WeekDayCodes.wednesday,
  WeekDay.thursday => WeekDayCodes.thursday,
  WeekDay.friday => WeekDayCodes.friday,
  WeekDay.saturday => WeekDayCodes.saturday,
  WeekDay.sunday => WeekDayCodes.sunday,
};

WeekDay? weekDayFromCode(String code) => switch (code) {
  WeekDayCodes.monday => WeekDay.monday,
  WeekDayCodes.tuesday => WeekDay.tuesday,
  WeekDayCodes.wednesday => WeekDay.wednesday,
  WeekDayCodes.thursday => WeekDay.thursday,
  WeekDayCodes.friday => WeekDay.friday,
  WeekDayCodes.saturday => WeekDay.saturday,
  WeekDayCodes.sunday => WeekDay.sunday,
  _ => null,
};

String slotStateToCode(SlotState value) => switch (value) {
  SlotState.free => SlotStateCodes.free,
  SlotState.taken => SlotStateCodes.taken,
  SlotState.blocked => SlotStateCodes.blocked,
  SlotState.past => SlotStateCodes.past,
};

SlotState? slotStateFromCode(String code) => switch (code) {
  SlotStateCodes.free => SlotState.free,
  SlotStateCodes.taken => SlotState.taken,
  SlotStateCodes.blocked => SlotState.blocked,
  SlotStateCodes.past => SlotState.past,
  _ => null,
};

String statsPeriodToCode(StatsPeriodKind value) => switch (value) {
  StatsPeriodKind.week => StatsPeriodCodes.week,
  StatsPeriodKind.month => StatsPeriodCodes.month,
};

StatsPeriodKind? statsPeriodFromCode(String code) => switch (code) {
  StatsPeriodCodes.week => StatsPeriodKind.week,
  StatsPeriodCodes.month => StatsPeriodKind.month,
  _ => null,
};

/// Vraća vrednost ili baca [UnknownCodeException].
T requireKnown<T>(T? value, String kind, String code) =>
    value ?? (throw UnknownCodeException(kind, code));
