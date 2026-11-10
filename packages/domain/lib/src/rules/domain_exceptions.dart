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
