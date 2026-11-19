import 'package:contract/contract.dart';
import 'package:domain/domain.dart';

import 'codes_mapping.dart';
import 'user_mapping.dart';

extension ReservationMapping on Reservation {
  ReservationDto toDto() => ReservationDto(
    id: id.value,
    fieldId: fieldId.value,
    userId: userId.value,
    startTime: startTime,
    endTime: endTime,
    totalPrice: totalPrice,
    status: reservationStatusToCode(status),
    paymentStatus: paymentStatusToCode(paymentStatus),
    checkedInAt: checkedInAt,
    cancellationReason: cancellationReason,
    createdAt: createdAt,
    customer: customer?.toDto(includeContact: true),
  );
}

extension ReservationDtoMapping on ReservationDto {
  /// Baca [UnknownCodeException] kada stanje ili plaćanje nisu poznati ovoj verziji.
  Reservation toDomain() => Reservation(
    id: ReservationId(id),
    fieldId: FieldId(fieldId),
    userId: UserId(userId),
    startTime: startTime,
    endTime: endTime,
    totalPrice: totalPrice,
    status: requireKnown(
      reservationStatusFromCode(status),
      'reservationStatus',
      status,
    ),
    paymentStatus: requireKnown(
      paymentStatusFromCode(paymentStatus),
      'paymentStatus',
      paymentStatus,
    ),
    checkedInAt: checkedInAt,
    cancellationReason: cancellationReason,
    createdAt: createdAt,
    customer: customer?.toDomain(),
  );

  /// Isto što [toDomain], ali nepoznat kod daje `null` umesto izuzetka.
  Reservation? toDomainOrNull() {
    try {
      return toDomain();
    } on UnknownCodeException {
      return null;
    }
  }
}

extension ReservationDtoListMapping on Iterable<ReservationDto> {
  /// Preskače rezervacije sa kodom koji ova verzija ne poznaje, pa jedan nov
  /// kod sa servera ne obara celu listu.
  List<Reservation> toDomainKnown() => [
    for (final dto in this) ?dto.toDomainOrNull(),
  ];
}

extension CreateReservationMapping on CreateReservationRequestDto {
  /// Podaci za `ReservationRepository.createReservation`. Korisnik ne stiže
  /// iz zahteva nego iz tokena, zato se prosleđuje odvojeno.
  ({FieldId fieldId, DateTime startTime, DateTime endTime}) toDomain() =>
      (fieldId: FieldId(fieldId), startTime: startTime, endTime: endTime);
}
