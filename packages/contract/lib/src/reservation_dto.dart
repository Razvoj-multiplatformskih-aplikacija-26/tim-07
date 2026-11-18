import 'json.dart';

/// Rezervacija kako je server vraća. Novac je ceo broj dinara, trenuci su UTC.
final class ReservationDto {
  final int id;
  final int fieldId;
  final int userId;
  final DateTime startTime;
  final DateTime endTime;
  final int totalPrice;

  /// Kod iz `ReservationStatusCodes`; nepoznat kod se čuva kakav je stigao.
  final String status;

  /// Kod iz `PaymentStatusCodes`.
  final String paymentStatus;
  final DateTime? checkedInAt;
  final String? cancellationReason;
  final DateTime createdAt;

  const ReservationDto({
    required this.id,
    required this.fieldId,
    required this.userId,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    this.checkedInAt,
    this.cancellationReason,
    required this.createdAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'fieldId': fieldId,
    'userId': userId,
    'startTime': instantToJson(startTime),
    'endTime': instantToJson(endTime),
    'totalPrice': totalPrice,
    'status': status,
    'paymentStatus': paymentStatus,
    if (checkedInAt case final checkedInAt?)
      'checkedInAt': instantToJson(checkedInAt),
    'cancellationReason': ?cancellationReason,
    'createdAt': instantToJson(createdAt),
  };

  factory ReservationDto.fromJson(Map<String, Object?> json) => ReservationDto(
    id: jsonInt(json, 'id'),
    fieldId: jsonInt(json, 'fieldId'),
    userId: jsonInt(json, 'userId'),
    startTime: jsonInstant(json, 'startTime'),
    endTime: jsonInstant(json, 'endTime'),
    totalPrice: jsonInt(json, 'totalPrice'),
    status: jsonString(json, 'status'),
    paymentStatus: jsonString(json, 'paymentStatus'),
    checkedInAt: jsonOptionalInstant(json, 'checkedInAt'),
    cancellationReason: jsonOptionalString(json, 'cancellationReason'),
    createdAt: jsonInstant(json, 'createdAt'),
  );
}

/// Telo zahteva `POST /reservations`.
///
/// Nema `userId`: server zna ko poziva samo iz tokena (odluka 11), a cenu računa sam.
final class CreateReservationRequestDto {
  final int fieldId;
  final DateTime startTime;
  final DateTime endTime;

  const CreateReservationRequestDto({
    required this.fieldId,
    required this.startTime,
    required this.endTime,
  });

  Map<String, Object?> toJson() => {
    'fieldId': fieldId,
    'startTime': instantToJson(startTime),
    'endTime': instantToJson(endTime),
  };

  factory CreateReservationRequestDto.fromJson(Map<String, Object?> json) =>
      CreateReservationRequestDto(
        fieldId: jsonInt(json, 'fieldId'),
        startTime: jsonInstant(json, 'startTime'),
        endTime: jsonInstant(json, 'endTime'),
      );
}

/// Telo zahteva za odbijanje i otkazivanje, razlog je neobavezan.
final class ReservationReasonRequestDto {
  final String? reason;

  const ReservationReasonRequestDto({this.reason});

  Map<String, Object?> toJson() => {'reason': ?reason};

  factory ReservationReasonRequestDto.fromJson(Map<String, Object?> json) =>
      ReservationReasonRequestDto(reason: jsonOptionalString(json, 'reason'));
}
