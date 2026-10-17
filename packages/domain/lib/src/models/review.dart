
import '../ids.dart';

/// Vrsta recenzije.
enum ReviewType {
  field,
  user,
}

/// Recenzija nakon završene rezervacije.
///
/// Korisnik ocenjuje teren, a vlasnik korisnika.
final class Review {
  final ReviewId id;

  /// Rezervacija na osnovu koje je ostavljena recenzija.
  final ReservationId reservationId;

  /// Korisnik koji ostavlja recenziju.
  final UserId reviewerId;

  /// Da li se ocenjuje teren ili korisnik.
  final ReviewType type;

  /// ID ocenjenog terena, ako je recenzija za teren.
  final FieldId? reviewedFieldId;

  /// ID ocenjenog korisnika, ako je recenzija za korisnika.
  final UserId? reviewedUserId;

  /// Ocena od 1 do 5.
  final int rating;

  /// Opcioni komentar.
  final String? comment;

  final DateTime createdAt;

  const Review({
    required this.id,
    required this.reservationId,
    required this.reviewerId,
    required this.type,
    this.reviewedFieldId,
    this.reviewedUserId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  /// Da li recenzija ocenjuje teren.
  bool get isFieldReview => type == ReviewType.field;

  /// Da li recenzija ocenjuje korisnika.
  bool get isUserReview => type == ReviewType.user;
}
