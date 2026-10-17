
import '../enums.dart';
import '../ids.dart';

/// Rezervacija sportskog terena.
///
/// Ovo je glavni domenski model Terenza.
/// Koriste ga i mobilna aplikacija i backoffice.
final class Reservation {
  final ReservationId id;

  /// Teren koji je rezervisan.
  final FieldId fieldId;

  /// Korisnik koji je napravio rezervaciju.
  final UserId userId;

  /// Početak i kraj rezervisanog termina.
  final DateTime startTime;
  final DateTime endTime;

  /// Ukupna cena u dinarima u trenutku rezervisanja.
  final int totalPrice;

  /// Trenutni status rezervacije.
  final ReservationStatus status;

  /// Evidencija plaćanja, bez online naplate u KT1.
  final PaymentStatus paymentStatus;

  /// Vreme kada je korisnik potvrdio dolazak.
  /// null znači da check-in nije izvršen.
  final DateTime? checkedInAt;

  /// Opcioni razlog otkazivanja ili odbijanja.
  final String? cancellationReason;

  /// Vreme kreiranja rezervacije.
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.fieldId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    this.paymentStatus = PaymentStatus.unpaid,
    this.checkedInAt,
    this.cancellationReason,
    required this.createdAt,
  });

  /// Trajanje rezervacije, bez ograničenja na 60 minuta.
  Duration get duration => endTime.difference(startTime);

  /// Da li je rezervacija aktivna i zauzima termin.
  bool get isActive =>
      status == ReservationStatus.pending ||
          status == ReservationStatus.confirmed;

  /// Vreme otvaranja check-in prozora.
  DateTime get checkInOpensAt =>
      startTime.subtract(const Duration(hours: 24));

  /// Poslednji dozvoljeni trenutak za check-in.
  DateTime get checkInDeadline =>
      startTime.subtract(const Duration(hours: 5));

  /// Da li je korisnik već potvrdio dolazak.
  bool get isCheckedIn => checkedInAt != null;

  /// Vraća novu rezervaciju sa izmenjenim podacima.
  ///
  /// Sam model ne odlučuje da li je promena dozvoljena.
  /// Ta pravila implementiramo u T06–T08.
  Reservation copyWith({
    ReservationStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? checkedInAt,
    String? cancellationReason,
  }) {
    return Reservation(
      id: id,
      fieldId: fieldId,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt,
    );
  }
}
