
import '../enums.dart';
import '../ids.dart';

/// Sportski teren koji vlasnik izdaje preko Terenza.
final class SportsField {
  final FieldId id;
  final UserId ownerId;

  final String name;
  final String description;
  final SportType sport;

  final String address;
  final String city;

  /// Cena jednog sata korišćenja u dinarima.
  final int pricePerHour;

  /// Kontakt broj za konkretan teren.
  final String contactPhone;

  /// Slike terena. Prazna lista znači da nema slika.
  final List<String> imageUrls;

  /// Vlasnik bira automatsko ili ručno potvrđivanje.
  final ConfirmationMode confirmationMode;

  /// Da li je teren aktivan i dostupan za rezervisanje.
  final bool isActive;

  SportsField({
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
    this.isActive = true,
  }) : imageUrls = List.unmodifiable(imageUrls);

  /// Kreira novu instancu sa izmenjenim podacima.
  SportsField copyWith({
    String? name,
    String? description,
    SportType? sport,
    String? address,
    String? city,
    int? pricePerHour,
    String? contactPhone,
    List<String>? imageUrls,
    ConfirmationMode? confirmationMode,
    bool? isActive,
  }) {
    return SportsField(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      sport: sport ?? this.sport,
      address: address ?? this.address,
      city: city ?? this.city,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      contactPhone: contactPhone ?? this.contactPhone,
      imageUrls: imageUrls ?? this.imageUrls,
      confirmationMode: confirmationMode ?? this.confirmationMode,
      isActive: isActive ?? this.isActive,
    );
  }
}
