import 'json.dart';

/// Sportski teren kako ga server vraća.
final class FieldDto {
  final int id;
  final int ownerId;
  final String name;
  final String description;

  /// Kod iz `SportCodes`.
  final String sport;
  final String address;
  final String city;

  /// Cena jednog sata u dinarima.
  final int pricePerHour;
  final String contactPhone;
  final List<String> imageUrls;

  /// Kod iz `ConfirmationModeCodes`.
  final String confirmationMode;
  final bool isActive;

  /// Kod iz `ApprovalStatusCodes`.
  final String approvalStatus;
  final String? rejectionReason;

  FieldDto({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.sport,
    required this.address,
    required this.city,
    required this.pricePerHour,
    required this.contactPhone,
    List<String> imageUrls = const [],
    required this.confirmationMode,
    required this.isActive,
    required this.approvalStatus,
    this.rejectionReason,
  }) : imageUrls = List.unmodifiable(imageUrls);

  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'name': name,
    'description': description,
    'sport': sport,
    'address': address,
    'city': city,
    'pricePerHour': pricePerHour,
    'contactPhone': contactPhone,
    'imageUrls': imageUrls,
    'confirmationMode': confirmationMode,
    'isActive': isActive,
    'approvalStatus': approvalStatus,
    'rejectionReason': ?rejectionReason,
  };

  factory FieldDto.fromJson(Map<String, Object?> json) => FieldDto(
    id: jsonInt(json, 'id'),
    ownerId: jsonInt(json, 'ownerId'),
    name: jsonString(json, 'name'),
    description: jsonString(json, 'description'),
    sport: jsonString(json, 'sport'),
    address: jsonString(json, 'address'),
    city: jsonString(json, 'city'),
    pricePerHour: jsonInt(json, 'pricePerHour'),
    contactPhone: jsonString(json, 'contactPhone'),
    imageUrls: json['imageUrls'] == null
        ? const []
        : jsonStrings(json, 'imageUrls'),
    confirmationMode: jsonString(json, 'confirmationMode'),
    isActive: jsonBool(json, 'isActive'),
    approvalStatus: jsonString(json, 'approvalStatus'),
    rejectionReason: jsonOptionalString(json, 'rejectionReason'),
  );
}

/// Telo zahteva za dodavanje (`POST /fields`) i izmenu (`PATCH /fields/:id`) terena.
///
/// Vlasnik se uzima iz tokena, a stanje odobrenosti određuje server.
final class SaveFieldRequestDto {
  final String name;
  final String description;
  final String sport;
  final String address;
  final String city;
  final int pricePerHour;
  final String contactPhone;
  final List<String> imageUrls;
  final String confirmationMode;
  final bool isActive;

  SaveFieldRequestDto({
    required this.name,
    required this.description,
    required this.sport,
    required this.address,
    required this.city,
    required this.pricePerHour,
    required this.contactPhone,
    List<String> imageUrls = const [],
    required this.confirmationMode,
    this.isActive = true,
  }) : imageUrls = List.unmodifiable(imageUrls);

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'sport': sport,
    'address': address,
    'city': city,
    'pricePerHour': pricePerHour,
    'contactPhone': contactPhone,
    'imageUrls': imageUrls,
    'confirmationMode': confirmationMode,
    'isActive': isActive,
  };

  factory SaveFieldRequestDto.fromJson(Map<String, Object?> json) =>
      SaveFieldRequestDto(
        name: jsonString(json, 'name'),
        description: jsonString(json, 'description'),
        sport: jsonString(json, 'sport'),
        address: jsonString(json, 'address'),
        city: jsonString(json, 'city'),
        pricePerHour: jsonInt(json, 'pricePerHour'),
        contactPhone: jsonString(json, 'contactPhone'),
        imageUrls: json['imageUrls'] == null
            ? const []
            : jsonStrings(json, 'imageUrls'),
        confirmationMode: jsonString(json, 'confirmationMode'),
        isActive: json['isActive'] == null ? true : jsonBool(json, 'isActive'),
      );
}

/// Odluka administratora o objavljivanju terena (`POST /fields/:id/review`).
final class FieldReviewRequestDto {
  /// `approved` ili `rejected` iz `ApprovalStatusCodes`.
  final String decision;
  final String? reason;

  const FieldReviewRequestDto({required this.decision, this.reason});

  Map<String, Object?> toJson() => {'decision': decision, 'reason': ?reason};

  factory FieldReviewRequestDto.fromJson(Map<String, Object?> json) =>
      FieldReviewRequestDto(
        decision: jsonString(json, 'decision'),
        reason: jsonOptionalString(json, 'reason'),
      );
}

/// Odgovor `GET /sports`: samo sportovi koji postoje na aktivnim, odobrenim
/// terenima. Brzi filter u aplikaciji se pravi iz ovoga, a ne iz hardkodovane liste.
final class SportsDto {
  final List<String> sports;

  SportsDto({required List<String> sports})
    : sports = List.unmodifiable(sports);

  Map<String, Object?> toJson() => {'sports': sports};

  factory SportsDto.fromJson(Map<String, Object?> json) =>
      SportsDto(sports: jsonStrings(json, 'sports'));
}
