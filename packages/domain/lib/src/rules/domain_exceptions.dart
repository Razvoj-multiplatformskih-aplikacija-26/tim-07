import 'reservation_validation_error.dart';

/// Operacija krši domensko pravilo.
///
/// Nosi tipiziranu grešku ([error]), pa server iz nje pravi kod greške za
/// mrežu, a klijent poruku, bez poređenja tekstova.
final class ReservationRuleViolation implements Exception {
  final ReservationValidationError error;

  const ReservationRuleViolation(this.error);

  @override
  String toString() => error.message;
}

/// Traženi zapis ne postoji.
final class EntityNotFound implements Exception {
  /// Vrsta zapisa, npr. `reservation` ili `field`.
  final String entity;
  final int id;

  const EntityNotFound(this.entity, this.id);

  @override
  String toString() => 'Zapis $entity #$id ne postoji.';
}
