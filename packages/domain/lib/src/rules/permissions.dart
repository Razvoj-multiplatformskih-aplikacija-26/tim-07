import '../enums.dart';
import '../models/app_user.dart';
import '../models/reservation.dart';
import '../models/sports_field.dart';
import 'field_approval.dart';

// Prava uloga na jednom mestu (odluke 4 i 9 u docs/kt2-decisions.md).
//
// Ove funkcije koriste i klijenti (da sakriju dugme koje server ionako odbija)
// i server (da odbije poziv). Pravila se ne pišu ni na jednom drugom mestu:
// nema `if (role == ...)` po ekranima ni po rutama.
//
// Funkcije odgovaraju samo na pitanje „sme li“. Vremenska pravila (rok od 5
// sati, prozor za check-in) su posebna i proveravaju se pravilima iz
// `reservation_validation.dart`.
//
// Kako server odgovara kada je odgovor „ne“:
//  - korisnik koji traži tuđu rezervaciju (`canViewReservation` je false): 404,
//    da ne sazna da zapis postoji;
//  - zabranjena akcija nad zapisom koji sme da vidi: 403 `forbidden`.

/// Aplikacija iz koje se korisnik prijavljuje.
enum ClientApp { mobile, backoffice }

/// Akcije nad rezervacijom koje klijent nudi kao dugmad.
enum ReservationAction { confirm, reject, cancel, checkIn }

/// Da li uloga sme da se prijavi u aplikaciju. Mobilna aplikacija je za
/// korisnike, backoffice za osoblje (vlasnike i administratore).
bool canSignIn(UserRole role, ClientApp app) => switch (app) {
  ClientApp.mobile => role == UserRole.user,
  ClientApp.backoffice => role == UserRole.owner || role == UserRole.admin,
};

bool _isOwnerOf(AppUser user, SportsField field) =>
    user.role == UserRole.owner && field.ownerId == user.id;

bool _isOwnReservation(AppUser user, Reservation reservation) =>
    user.role == UserRole.user && reservation.userId == user.id;

// ---------------------------------------------------------------------------
// Rezervacije
// ---------------------------------------------------------------------------

/// Rezervaciju pravi samo korisnik, uvek za sebe.
bool canCreateReservation(AppUser user) => user.role == UserRole.user;

/// Korisnik vidi samo svoje, vlasnik rezervacije na svojim terenima,
/// administrator sve. [field] je teren te rezervacije.
bool canViewReservation(
  AppUser user,
  Reservation reservation,
  SportsField field,
) => switch (user.role) {
  UserRole.user => _isOwnReservation(user, reservation),
  UserRole.owner => _isOwnerOf(user, field),
  UserRole.admin => true,
};

/// Potvrđuje samo vlasnik tog terena, i samo rezervaciju na čekanju.
bool canConfirmReservation(
  AppUser user,
  Reservation reservation,
  SportsField field,
) => _isOwnerOf(user, field) && reservation.status == ReservationStatus.pending;

/// Odbija samo vlasnik tog terena, i samo rezervaciju na čekanju.
/// Odbijena rezervacija prelazi u stanje „otkazana“.
bool canRejectReservation(
  AppUser user,
  Reservation reservation,
  SportsField field,
) => _isOwnerOf(user, field) && reservation.status == ReservationStatus.pending;

/// Otkazuje se aktivna rezervacija (na čekanju ili potvrđena): korisnik samo
/// svoju, vlasnik na svom terenu, administrator bilo koju (rešavanje
/// prijavljenih nepravilnosti). Završena i otkazana su konačna stanja.
bool canCancelReservation(
  AppUser user,
  Reservation reservation,
  SportsField field,
) {
  if (!reservation.isActive) return false;
  return switch (user.role) {
    UserRole.user => _isOwnReservation(user, reservation),
    UserRole.owner => _isOwnerOf(user, field),
    UserRole.admin => true,
  };
}

/// Dolazak potvrđuje samo korisnik koji je rezervisao, jednom, kada je
/// rezervacija potvrđena. Prozor od 24 do 5 sati je posebno pravilo.
bool canCheckInReservation(AppUser user, Reservation reservation) =>
    _isOwnReservation(user, reservation) &&
    reservation.status == ReservationStatus.confirmed &&
    !reservation.isCheckedIn;

/// Sve akcije koje [user] sme sada nad rezervacijom, za dugmad na ekranu.
Set<ReservationAction> allowedReservationActions(
  AppUser user,
  Reservation reservation,
  SportsField field,
) => {
  if (canConfirmReservation(user, reservation, field))
    ReservationAction.confirm,
  if (canRejectReservation(user, reservation, field)) ReservationAction.reject,
  if (canCancelReservation(user, reservation, field)) ReservationAction.cancel,
  if (canCheckInReservation(user, reservation)) ReservationAction.checkIn,
};

// ---------------------------------------------------------------------------
// Tereni
// ---------------------------------------------------------------------------

/// Javnost vidi aktivne i odobrene terene, vlasnik i svoje (i neodobrene),
/// administrator sve. [user] je `null` kada niko nije prijavljen.
bool canViewField(AppUser? user, SportsField field) {
  if (isFieldPublic(field)) return true;
  if (user == null) return false;
  return user.role == UserRole.admin || _isOwnerOf(user, field);
}

/// Teren objavljuje vlasnik.
bool canCreateField(AppUser user) => user.role == UserRole.owner;

/// Podatke, cenu, radno vreme i blokade terena menja samo vlasnik tog terena.
/// Administrator ne menja tuđe terene, samo ih odobrava.
bool canManageField(AppUser user, SportsField field) => _isOwnerOf(user, field);

/// Objavljivanje terena odobrava ili odbija administrator. Dozvoljene prelaze
/// određuje `canTransitionApprovalStatus`.
bool canReviewField(AppUser user) => user.role == UserRole.admin;

// ---------------------------------------------------------------------------
// Statistika i nalozi
// ---------------------------------------------------------------------------

/// Statistiku zauzetosti vidi vlasnik (za svoje terene) i administrator (za sve).
bool canViewStatistics(AppUser user) =>
    user.role == UserRole.owner || user.role == UserRole.admin;

bool canViewFieldStatistics(AppUser user, SportsField field) =>
    user.role == UserRole.admin || _isOwnerOf(user, field);

/// Spisak naloga i deaktivaciju naloga sme samo administrator.
bool canManageUsers(AppUser user) => user.role == UserRole.admin;
