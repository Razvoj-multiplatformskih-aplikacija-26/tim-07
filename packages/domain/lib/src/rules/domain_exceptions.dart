import '../enums.dart';
import 'reservation_validation_error.dart';

final class ReservationRuleViolation implements Exception {
  final ReservationValidationError error;

  const ReservationRuleViolation(this.error);

  @override
  String toString() => error.message;
}

final class EntityNotFound implements Exception {
  final String entity;
  final int id;

  const EntityNotFound(this.entity, this.id);

  @override
  String toString() => 'Zapis $entity #$id ne postoji.';
}

final class ApprovalTransitionNotAllowed implements Exception {
  final ApprovalStatus from;
  final ApprovalStatus to;

  const ApprovalTransitionNotAllowed(this.from, this.to);

  @override
  String toString() => 'Teren nije moguće prevesti iz stanja ${from.name} u ${to.name}.';
}
