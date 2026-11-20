import 'package:contract/contract.dart';
import 'package:relic/relic.dart';

import 'cors.dart';
import 'handlers.dart';
import 'http.dart';
import 'sessions.dart';

/// Sastavlja ceo server: spisak ruta (adresa + HTTP metoda → funkcija koja je obrađuje)
/// i "slojeve" kroz koje svaki zahtev prolazi (vidi kraj funkcije).
///
/// Dva omotača oko funkcija u ovom spisku:
/// - `signedIn(...)`: zahtev MORA da nosi važeći token prijave, inače server odmah
///   odgovara 401 i funkcija se ni ne pokreće;
/// - `optional(...)`: prijava nije obavezna (javni katalog), ali ako token stigne,
///   server zna ko poziva, pa može da pokaže i ono što je samo za njega.
/// Rute bez omotača (health, login, sports) su potpuno javne.
///
/// Ko sme šta (uloga, vlasništvo, stanje) NE proverava ovaj fajl nego svaka funkcija
/// u `handlers.dart`, pozivajući pravila iz `domain/permissions.dart`.
Handler buildHandler(TerenzoHandlers handlers, SessionHandlers sessions, {required List<String> corsOrigins}) {
  final signedIn = sessions.signedIn;
  final optional = sessions.optionallySignedIn;
  final router = RelicRouter()
    // ---- Provera i prijava ----
    // Provera da server radi (koristi je Docker/ručna provera). Vraća tekst "ok".
    ..get(ApiPaths.health, (request) => Response.ok(body: Body.fromString('ok')))
    // Prijava: prima e-mail i lozinku, proverava heš lozinke, pa vraća nalog, rok i TOKEN.
    // Pogrešna lozinka: 401. Deaktiviran nalog (sa tačnom lozinkom): 403.
    ..post(ApiPaths.login, sessions.logIn)
    // "Ko sam ja": vraća nalog iz tokena. Aplikacija ovo zove pri pokretanju da vidi da li je
    // sačuvana prijava još važeća.
    ..get(ApiPaths.me, signedIn(sessions.current))
    // Odjava: server nema stanje sesije (token je samostalan), pa samo potvrđuje (204).
    // Token zaista briše klijent iz svog skladišta.
    ..delete(ApiPaths.me, signedIn(sessions.logOut))
    // ---- Tereni (katalog je javan) ----
    // Spisak sportova koji postoje na javnim terenima: odavde aplikacija pravi brzi filter
    // (čipove), umesto fiksne liste.
    ..get(ApiPaths.sports, handlers.sports)
    // Spisak terena po stranama, sa filterima (sport, grad, pretraga). Gost vidi samo javne
    // terene (odobrene i aktivne); vlasnik uz njih i svoje neodobrene; administrator sve.
    ..get(ApiPaths.fields, optional(handlers.fields))
    // Vlasnik objavljuje novi teren. Teren nastaje kao "čeka odobrenje" dok ga administrator
    // ne odobri. Ko nije vlasnik: 403.
    ..post(ApiPaths.fields, signedIn(handlers.createField))
    // Tereni koji čekaju odobrenje. Samo administrator.
    ..get(ApiPaths.fieldsAwaitingApproval, signedIn(handlers.fieldsAwaitingApproval))
    // Jedan teren. Neodobren ili neaktivan teren vide samo njegov vlasnik i administrator,
    // ostalima je "nije pronađen" (404).
    ..get('${ApiPaths.fields}/:id', optional(handlers.field))
    // Vlasnik menja podatke svog terena (naziv, cena, adresa...). Tuđi teren: 403.
    ..patch('${ApiPaths.fields}/:id', signedIn(handlers.updateField))
    // Slobodni i zauzeti termini terena za jedan dan (?date=GGGG-MM-DD). Server ih računa iz
    // radnog vremena, rezervacija i blokada, istim pravilom koje klijent koristi pri rezervisanju.
    ..get('${ApiPaths.fields}/:id/availability', optional(handlers.availability))
    // ---- Radno vreme i blokade terena ----
    // Radno vreme terena po danima u nedelji.
    ..get('${ApiPaths.fields}/:id/schedule', optional(handlers.schedule))
    // Vlasnik zamenjuje radno vreme celog terena. Odbija se (409) ako neka postojeća rezervacija
    // ne bi ostala u novom radnom vremenu.
    ..put('${ApiPaths.fields}/:id/schedule', signedIn(handlers.replaceSchedule))
    // Blokade terena (održavanje, događaji), po stranama.
    ..get('${ApiPaths.fields}/:id/blocked-periods', optional(handlers.blockedPeriods))
    // Vlasnik blokira period na svom terenu. Odbija se (409) ako se preklapa sa potvrđenom
    // rezervacijom, a posle blokade termin se više ne može rezervisati.
    ..post('${ApiPaths.fields}/:id/blocked-periods', signedIn(handlers.addBlockedPeriod))
    // Vlasnik uklanja blokadu sa svog terena; termin ponovo može da se rezerviše.
    ..delete('${ApiPaths.fields}/:id/blocked-periods/:blockId', signedIn(handlers.removeBlockedPeriod))
    // Administrator odobrava ili odbija objavljivanje terena (uz razlog kod odbijanja).
    ..post('${ApiPaths.fields}/:id/review', signedIn(handlers.reviewField))
    // ---- Rezervacije (sve traže prijavu) ----
    // Spisak rezervacija po stranama, sa filterima, pretragom po korisniku i sortiranjem.
    // Korisnik vidi samo svoje, vlasnik one na svojim terenima (uz podatke o korisniku),
    // administrator sve.
    ..get(ApiPaths.reservations, signedIn(handlers.reservations))
    // Korisnik rezerviše termin. Server uzima korisnika iz tokena (ne iz tela zahteva),
    // proverava sva pravila u transakciji i vraća 201, ili 409 ako je termin već zauzet.
    ..post(ApiPaths.reservations, signedIn(handlers.createReservation))
    // Jedna rezervacija. Tuđa rezervacija vraća 404 (ne 403), da se ne otkrije da postoji.
    ..get('${ApiPaths.reservations}/:id', signedIn(handlers.reservation))
    // Vlasnik potvrđuje rezervaciju na čekanju za svoj teren. Korisnik: 403.
    ..post('${ApiPaths.reservations}/:id/confirm', signedIn(handlers.confirm))
    // Vlasnik odbija rezervaciju na čekanju (uz razlog); ona postaje otkazana.
    ..post('${ApiPaths.reservations}/:id/reject', signedIn(handlers.reject))
    // Otkazivanje: korisnik svoju rezervaciju do roka (5 sati pre početka), vlasnik na svom
    // terenu i administrator do početka termina. Posle roka: 422.
    ..post('${ApiPaths.reservations}/:id/cancel', signedIn(handlers.cancel))
    // Korisnik potvrđuje dolazak na svoju potvrđenu rezervaciju, u dozvoljenom prozoru
    // (od 24 do 5 sati pre početka).
    ..post('${ApiPaths.reservations}/:id/check-in', signedIn(handlers.checkIn))
    // ---- Statistika i nalozi ----
    // Zauzetost terena za nedelju ili mesec. Vlasnik za svoje terene, administrator za sve.
    ..get(ApiPaths.stats, signedIn(handlers.statistics))
    // Spisak svih naloga (uz telefon i datum registracije). Samo administrator, vlasniku
    // i korisniku je 403.
    ..get(ApiPaths.users, signedIn(handlers.users))
    // Administrator deaktivira ili ponovo aktivira tuđi nalog (svoj ne sme).
    ..patch('${ApiPaths.users}/:id', signedIn(handlers.setUserActive))
    // Sve ostale adrese: 404 u istom obliku greške kao i ostale.
    ..fallback = respondWith((request) => errorResponse(const ErrorDto(code: ErrorCodes.notFound)));
  // "Slojevi" kroz koje prolazi svaki zahtev, redom: zapis u log, provera da li je veb adresa
  // pozivaoca dozvoljena (CORS), hvatanje svih grešaka i njihovo pretvaranje u kod greške,
  // pa tek onda ruta iz spiska iznad.
  return const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(allowOrigins(corsOrigins))
      .addMiddleware(handleErrors())
      .addHandler(router.asHandler);
}
