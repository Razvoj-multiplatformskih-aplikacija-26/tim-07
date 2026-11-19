# KT2: mapa koda i tokovi podataka

Ovo je za učenje pred odbranu. Cilj nije sintaksa nego da znaš **šta se dešava, kojim redom i u kom fajlu**. Svaka stavka je u obliku `fajl:linija` `ime`, a ime je funkcija ili klasa koja se tamo nalazi. Brojevi linija važe za `main` na dan pisanja; ako se pomere, ime pronađi pretragom.

## 0. Slika celog sistema u jednoj rečenici

Dva klijenta (mobilna za korisnike, backoffice za vlasnike i administratora) **ne pričaju sa bazom**, nego preko HTTP-a sa serverom. Server drži bazu i **konačnu reč o pravilima**. Pravila su napisana **jednom** u paketu `domain` i koriste ih i server i oba klijenta.

| Sloj | Folder | Šta radi (jednom rečenicom) |
| ---- | ------ | --------------------------- |
| Domen | `packages/domain` | Modeli (`Reservation`, `AppUser`), **pravila** (preklapanje, rokovi, prava) i **portovi** (interfejsi za izvore podataka). Ne zna za HTTP, bazu ni ekran. |
| Ugovor | `packages/contract` | Kako podaci izgledaju na mreži (JSON, `*Dto`), kodovi grešaka, adrese ruta. |
| Mapiranje | `packages/mapping` | Prevodi domen ⇄ DTO i domenske greške ⇄ kodove grešaka. |
| Poruke | `packages/messages` | Jedino mesto koje pravi tekst greške na srpskom iz koda greške. |
| Klijent | `packages/api_client` | Priča HTTP sa serverom (`http` paket), baca dva izuzetka: server ne radi, server je odbio. |
| Token | `packages/session_storage` | Gde se na uređaju čuva token prijave. |
| Bloc-ovi | `packages/blocs` | Stanje ekrana (učitavanje, podaci, prazno, greška) i događaji. Rade samo preko portova iz domena. |
| Aplikacije | `apps/mobile`, `apps/backoffice` | Ekrani: šalju događaje Bloc-u i crtaju njegovo stanje. Nema pravila ni HTTP-a. |
| Server | `apps/server` | Rute, prijava, provera prava, transakcije i PostgreSQL. |

Portovi su u `packages/domain/lib/src/repositories/` (`reservation_repository.dart`, `auth_repository.dart`, ...). To je razlog zašto isti Bloc radi i nad lažnim repozitorijumom u testovima i nad HTTP-om u aplikaciji: Bloc zna samo za interfejs.

## 1. Glavni tok: korisnik rezerviše termin (mobilna → server → baza)

Ovo je najverovatnije pitanje. Prati ga redom.

**Klijent**
1. Korisnik klikne „Potvrdi rezervaciju“: `apps/mobile/lib/screens/reservation_form_screen.dart:240` `ReservationFormSubmitted`. Ekran samo šalje događaj.
2. Bloc proveri unos istim pravilima iz domena (da ne šalje ono što je očigledno loše), pa pozove port: `packages/blocs/lib/src/reservation_form/reservation_form_bloc.dart:322` `_onSubmitted` → linija 354 `reservations.createReservation(...)`. Dok traje, stanje je `ReservationFormSubmitting` (dugme se zaključava).
3. Port je u aplikaciji `HttpReservationRepository`: `packages/api_client/lib/src/http_reservation_repository.dart:137` `createReservation`. On pravi `CreateReservationRequestDto` i zove `ApiClient`.
4. `packages/api_client/lib/src/api_client.dart:68` `_send`: čita token iz skladišta, stavlja `Authorization: Bearer ...`, šalje zahtev sa **timeout-om od 10 sekundi** (`timeout`, linija 92). Ako nema mreže ili istekne vreme, baca `ServerUnreachableException` (linije 94 i 96).

**Server**
5. Ruta: `apps/server/lib/src/app.dart:31` `ApiPaths.reservations` → `signedIn(handlers.createReservation)`. `signedIn` je middleware koji **prvo proveri token** pa tek onda pusti zahtev (`apps/server/lib/src/sessions.dart:42` `signedIn`).
6. Handler: `apps/server/lib/src/handlers.dart:212` `createReservation`. Redom: ko je pozivalac iz tokena (`actorOf`), sme li da rezerviše (`canCreateReservation`, `packages/domain/lib/src/rules/permissions.dart:46`), čita telo, vidi li teren. **`userId` se uzima iz tokena, ne iz tela zahteva**: klijent ne može da rezerviše u tuđe ime.
7. Poslovna logika u transakciji: `apps/server/lib/src/postgres_terenzo.dart:60` `createReservation`. Redom:
   - proveri vreme (`validateReservationTime`, `packages/domain/lib/src/rules/reservation_validation.dart:14`),
   - **zaključa red terena** (`fieldForUpdate`) da dve istovremene rezervacije ne mogu da ga čitaju zajedno,
   - pozove **isto pravilo koje koristi i klijent**: `validateReservationSlot` (`reservation_validation.dart:83`): preklapanje, radno vreme, blokade,
   - upiše rezervaciju sa stanjem `pending` (ručna potvrda) ili `confirmed` (automatska) prema terenu.
8. **Poslednja linija odbrane je baza:** `apps/server/migrations/20261119100000_terenzo.sql:69` tabela `reservations` ima `EXCLUDE USING gist` ograničenje (`reservations_no_double_booking`, linija 82) koje fizički ne dozvoljava dva preklapajuća aktivna termina na istom terenu. Ako dva korisnika stignu u istoj milisekundi, jedan prolazi, a drugom baza vrati grešku `23P01`, a kod je pretvara u `SlotAlreadyTaken` (`postgres_terenzo.dart:110`). Zato je odgovor na „šta ako dvoje istovremeno“: **baza, ne klijent i ne server kod**.
9. Server odgovara `201` sa rezervacijom (`handlers.dart:212`, `json(201, ...)`), ili greškom (tok greške je u sekciji 5).

**Nazad u klijentu**
10. `ApiClient._answer` (`packages/api_client/lib/src/api_client.dart:102`) za 2xx vrati JSON, a za grešku baci `ServerRejectedException(ErrorDto)`.
11. Bloc: uspeh → `ReservationFormSucceeded` (ekran se zatvara, obaveštenje), odbijanje → `ReservationFormRejected` sa porukom, **unos ostaje**, a podaci za proveru se ponovo čitaju (`_reloadQuietly`, linija 389), jer su verovatno zastareli. Nema servera → `ReservationFormFailed`.

## 2. Prijava, token i istek (login)

1. Ekran: `apps/mobile/lib/screens/sign_in_screen.dart:11` `SignInScreen` šalje događaj u `AuthBloc` (`packages/blocs/lib/src/auth/auth_bloc.dart:15` `AuthBloc`).
2. `HttpSessionRepository.logIn` (`packages/api_client/lib/src/http_session_repository.dart:20`) šalje `POST /auth/login`.
3. Server: `apps/server/lib/src/sessions.dart:61` `logIn`:
   - nađe nalog po e-mailu i proveri lozinku (`verifyPassword`, linija 65). Lozinke u bazi su **samo heš** (Argon2id, `apps/server/lib/src/passwords.dart:10` `hashPassword`). Ako naloga nema, svejedno se računa heš (`_noAccountHash`), da se po trajanju ne vidi da li nalog postoji;
   - deaktiviran nalog dobija `403 account_deactivated`, ali tek posle tačne lozinke (linija 68);
   - pravi **JWT** (linija 75) sa ulogom, vremenom izdavanja i **istekom** (`SESSION_TTL_MINUTES`, podrazumevano 480), potpisan tajnom iz `.env`.
4. Klijent vrati `SessionDto` sa tokenom; `AuthBloc` proveri da li uloga sme u ovu aplikaciju: `canSignIn` (`packages/domain/lib/src/rules/permissions.dart:30`, poziv u `auth_bloc.dart:101`). Zato korisnik u backoffice-u dobija „Pristup odbijen.“ **iako je lozinka tačna**.
5. Token se čuva preko `SessionStore` porta: `packages/session_storage/lib/src/create_session_store.dart:10` `createSessionStore` (bezbedno skladište platforme, a u pregledaču `localStorage`). **Lozinka se nikad ne čuva.**
6. **Restart aplikacije:** `AuthBloc._onStarted` (`auth_bloc.dart:32`) pozove `restore` (`http_session_repository.dart:47`), tj. `GET /auth/me` sa sačuvanim tokenom. Važeći token → ostaje prijavljen, nevažeći se briše.
7. **Svaki zahtev posle toga:** `signedIn` (`sessions.dart:42`) → `_verify` (`sessions.dart:91`) proveri potpis, istek i da je nalog još aktivan (linija 119).
8. **Istek:** server vrati `401 token_expired`. `ApiClient._answer` (`packages/api_client/lib/src/api_client.dart:102`) obriše token i javi na stream `expirations`; `AuthBloc` ga sluša (`auth_bloc.dart:27`), pa aplikacija vrati korisnika na prijavu uz „Prijava je istekla. Prijavite se ponovo.“ (`packages/messages/lib/src/error_messages.dart:15`).
9. **Odjava** briše token i rezervacije učitane za tog korisnika.

## 3. Vlasnik potvrđuje ili otkazuje rezervaciju (backoffice) i prava

1. Backoffice: `apps/backoffice/lib/actions/reservation_actions.dart:26` `runReservationAction` (za otkazivanje traži potvrdu u dijalogu) → `ReservationBloc` (`packages/blocs/lib/src/reservations/reservation_bloc.dart:166` `_performAction`: stanje učitavanja, akcija, ponovno učitavanje liste).
2. Server: `apps/server/lib/src/handlers.dart:228` `confirm` i `:259` `cancel`. Prvo `_visibleReservation` (`handlers.dart:327`): vidi li pozivalac uopšte tu rezervaciju. **Tuđa rezervacija je `404`, ne `403`**, da se ne otkrije da postoji.
3. **Prava su u domenu**, na jednom mestu: `packages/domain/lib/src/rules/permissions.dart` (`canConfirmReservation` :61, `canCancelReservation` :78, `canManageField` :128). Klijent ih koristi da **sakrije dugme**, a server da **odbije poziv**. Ako neko pošalje `curl` mimo aplikacije, server svejedno proverava.
4. Promena stanja: `postgres_terenzo.dart:115` `changeStatus(from, to)`: menja samo ako je rezervacija **još u stanju `from`**. Ako je u međuvremenu promenjena (vlasnik potvrđuje, a korisnik je upravo otkazao), dobija se `409 invalid_status_transition`.
5. Stanja se i sama menjaju s vremenom: `packages/domain/lib/src/rules/reservation_auto_status.dart:21` `resolveReservationStatus` (rezervacija na čekanju kojoj je istekao rok postaje otkazana). Server to primenjuje pre čitanja (`postgres_terenzo.dart:24` `refreshStatuses`).

## 4. Tabela rezervacija: filteri, pretraga, sortiranje i strane

1. Ekran: `apps/backoffice/lib/screens/reservations_page.dart:18` `ReservationsPage` + traka `apps/backoffice/lib/widgets/reservation_filters.dart:15` `ReservationFilters`. Oba samo šalju događaje.
2. `ReservationListBloc` (`packages/blocs/lib/src/reservation_list/reservation_list_bloc.dart:171`) svaku promenu pretvara u **jedan objekat upita** `ReservationQuery` (`packages/domain/lib/src/models/reservation_query.dart`) i traži jednu stranu. Promena filtera vraća na prvu stranu. Pretraga čeka 300 ms posle poslednjeg slova, a zastareo odgovor se odbacuje (brojač zahteva).
3. `HttpReservationRepository.searchReservations` (`http_reservation_repository.dart:83`) pretvara upit u parametre (`?status=...&search=...&sort=...&limit=...&offset=...`).
4. Server: `handlers.dart:147` `reservations` čita parametre, prvo suzi na rezervacije koje pozivalac sme da vidi, pa primeni **isto pravilo iz domena**: `packages/domain/lib/src/rules/reservation_search.dart:31` `searchReservations` (filteri, pretraga bez dijakritika, stabilno sortiranje, strana). Vlasnik uz svaku rezervaciju dobija i podatke o korisniku (`customer`).

## 5. Put jedne greške do poruke (omiljeno pitanje)

Primer: `slot_taken`. Ista putanja važi za svaku grešku.

1. **Pravilo u domenu** vrati tipiziranu grešku, npr. `SlotAlreadyTaken` (`packages/domain/lib/src/rules/reservation_validation_error.dart`), ili baza odbije upis (tok 1, korak 8).
2. **Server pretvara grešku u kod:** `apps/server/lib/src/http.dart:16` `errorOf` → `packages/mapping/lib/src/error_mapping.dart:117` `failureOf` daje `ErrorDto(code: 'slot_taken')`. **Server nikad ne šalje gotov tekst**, samo kod i podatke.
3. **HTTP status** po kodu je u `packages/contract/lib/src/error_dto.dart:86` `httpStatusFor` (`slot_taken` je `409`, zabranjeno je `403`, nije pronađeno `404`, pravila `422`). Kodovi su u `ErrorCodes` (`error_dto.dart:8`).
4. **Klijent prima:** `ApiClient._answer` baca `ServerRejectedException`.
5. **Tekst na srpskom:** `packages/messages/lib/src/error_messages.dart:46` `errorMessage` (po kodu) i `:131` `describeError` (za bilo koji izuzetak: nikad ne vraća tehnički tekst). To je **jedino mesto sa tekstom grešaka**.
6. **Bloc** stavi poruku u stanje, **ekran je samo prikaže**.
7. Isti tekst dobija i lokalna provera pravila (kada klijent sam odbije unos), pa korisnik ne vidi razliku ko je proverio.
8. **Stara verzija aplikacije:** nepoznat kod → `ErrorDto.isKnown` je `false` → opšta poruka „Došlo je do greške. Pokušajte ponovo.“, ne pad aplikacije.
9. **Broj u poruci** (npr. „5 sati“) dolazi iz `details` koje server šalje, pa promena roka ne traži novu verziju aplikacije.

## 6. Gde su pravila i kako se menja pravilo uživo

- Rok za otkazivanje i check-in: `packages/domain/lib/src/models/reservation.dart:76` `checkInClosesHoursBefore = 5`. Koristi ga `validateCancellation` (`reservation_validation.dart:58`) i `resolveReservationStatus`.
- Preklapanje i radno vreme: `validateReservationSlot` (`reservation_validation.dart:83`), slobodni termini: `packages/domain/lib/src/rules/availability.dart:27` `calculateAvailability`.
- Blokade: `packages/domain/lib/src/rules/blocked_period_validation.dart:64` `validateBlockedPeriod` (ne sme preko potvrđene rezervacije).
- Radno vreme preko postojećih rezervacija: `packages/domain/lib/src/rules/field_schedule_validation.dart:100` `validateScheduleAgainstReservations` (server: `postgres_terenzo.dart:260` `replaceSchedules`).

**Izmena uživo (5 → 3 sata):** promeni konstantu → `dart test` u `domain`, `mapping`, `messages`, `api_client` (padaju testovi koji pišu staro pravilo, to je očekivano) → `docker compose up -d --build server` → ponovo pokreni klijente. Poruka dobija novi broj sama, jer ga server šalje u `details`. Aplikacije se **ne menjaju**.

## 7. Zaustavljen server, istekla prijava, tuđ zapis, akcija mimo aplikacije

| Situacija | Šta se dešava | Gde |
| --------- | ------------- | --- |
| Server ne radi | Zahtev ne uspe ili istekne posle 10 s → `ServerUnreachableException` → „Server trenutno nije dostupan.“ + „Pokušaj ponovo“. Backoffice lista se sama oporavi (osvežava se na 30 s). | `packages/api_client/lib/src/api_client.dart:94-96`, `packages/messages/lib/src/error_messages.dart:12` |
| Istekla prijava | `401 token_expired` → token se briše → vraća na prijavu. | `packages/api_client/lib/src/api_client.dart:102`, `auth_bloc.dart:27` |
| Tuđ zapis | `404 not_found` (ne `403`). | `handlers.dart:327` |
| Akcija mimo aplikacije (`curl`) | Token se proverava svaki put (`401`), prava svaki put (`403`), telo se validira (`400`). | `sessions.dart:42`, `permissions.dart`, `http.dart` |
| Lažan ili pokvaren token | `401 invalid_token`. | `sessions.dart:91` |
| Korisnik u backoffice-u | Lozinka prolazi, ali `canSignIn` odbija: „Pristup odbijen.“ | `auth_bloc.dart:101` |

## 8. Radno vreme, blokade, kalendar, statistika

- **Radno vreme:** `FieldManagementBloc` (`packages/blocs/lib/src/field_management/field_management_bloc.dart:172`) → `PUT /fields/:id/schedule` → server `replaceSchedules` (`postgres_terenzo.dart:260`) odbija promenu koja ostavlja rezervaciju van radnog vremena (`409 schedule_conflicts_with_reservations`).
- **Blokade:** `BlockedPeriodsBloc`, server `addBlockedPeriod` (`postgres_terenzo.dart:283`) u transakciji uz zaključan teren, kao i rezervacija: istovremena blokada i rezervacija ne mogu obe da uspeju.
- **Kalendar:** `CalendarBloc` (`packages/blocs/lib/src/calendar/calendar_bloc.dart:195`) učitava podatke za opseg, a redove (slobodno/zauzeto/blokirano) računa domen: `packages/domain/lib/src/rules/field_calendar.dart:157` `buildFieldCalendarDay`.
- **Slobodni termini u mobilnoj:** `AvailabilityBloc` (`packages/blocs/lib/src/availability/availability_bloc.dart:87`) ← `GET /fields/:id/availability` (`handlers.dart:110`) ← `calculateAvailability`. Isto pravilo kao pri rezervisanju, pa ono što se nudi uvek prolazi proveru.
- **Vreme:** server šalje trenutke u UTC, a klijent ih pretvara u lokalno (`toLocal()` u `packages/mapping/lib/src/reservation_mapping.dart:24` i `api_client`). Radno vreme je lokalno (`"08:00"`).

## 9. Baza, pokretanje i seed

- Šema i ograničenja: `apps/server/migrations/*.sql` (migracije pokreće `dbmate`, `compose.yaml` servis `migrate`, **ne server**).
- Pokretanje: `apps/server/bin/server.dart:8` `main` čita `.env`, otvara bazu, pozove `seedDemoData` (`apps/server/lib/src/seed.dart:16`, upisuje samo nad **praznom** bazom), sastavi rute (`apps/server/lib/src/app.dart:9` `buildHandler`) i sluša.
- CORS (koji pregledač sme da zove server): `apps/server/lib/src/cors.dart:5` `allowOrigins`, dozvoljeni izvori su u `.env` (`CORS_ORIGINS`).
- Redosled obrade zahteva: `apps/server/lib/src/app.dart:41`: `logRequests` → `allowOrigins` → `handleErrors` (hvata sve izuzetke i pravi `ErrorDto`) → ruta.
- Kako klijenti nalaze server: mobilna `apps/mobile/lib/server_address.dart:12` `serverAddress` (`10.0.2.2` na Android emulatoru, inače `localhost`, ili `--dart-define=SERVER_URL=...`), a sve HTTP repozitorijume sklapa `apps/mobile/lib/data/mobile_server.dart:10` `MobileServer`. Backoffice: `apps/backoffice/lib/main.dart`.

## 10. Pitanja koja mogu da ti postave

| Pitanje | Kratak odgovor | Gde |
| ------- | -------------- | --- |
| Zašto pravila nisu samo u klijentu? | Klijent se može zaobići (`curl`) ili je zastareo. Konačnu reč ima server, a baza čuva ono što se ne sme prekršiti. | odluka 2, tok 1 korak 8 |
| Šta ako dvoje rezervišu isti termin istovremeno? | Prvi dobija `201`, drugi `409 slot_taken`. Baza ne dozvoljava preklapanje (`EXCLUDE`), plus zaključavanje terena u transakciji. | `migrations/...sql:82`, `postgres_terenzo.dart:60` |
| Zašto server ne šalje poruku greške? | Jezik i tekst su stvar klijenta, stara aplikacija ne sme da prikaže pogrešan tekst, a ista greška izgleda isto bez obzira ko je proverio. | `error_messages.dart`, odluka 13 |
| Čemu portovi (`ReservationRepository`)? | Bloc ne zna odakle su podaci: isti Bloc radi sa lažnim izvorom u testovima i sa HTTP-om. | `packages/domain/lib/src/repositories/` |
| Gde je token i šta ako se ukrade? | Na uređaju u bezbednom skladištu (u pregledaču `localStorage`, slabije). Ističe na serveru (8 h), a deaktiviran nalog gubi pristup odmah. | `create_session_store.dart:10`, `sessions.dart:119` |
| Zašto Argon2id? | Sporo, memorijski zahtevno heširanje, otporno na pogađanje; lozinka se nikad ne čuva. | `passwords.dart:10` |
| Šta ako stigne treći klijent (javni veb)? | Server i domen se ne menjaju. Veb koristi iste pakete (`api_client` radi u pregledaču), dodaje se njegovo poreklo u `CORS_ORIGINS`, a bez prijave vidi samo javni katalog. | odluke 8, 10, 11 |
| Kako klijent saznaje za tuđu promenu? | Povlačenjem: osvežava pri otvaranju i na 30 s u backoffice-u. Server bi ga ionako odbio (`409`) ako radi nad zastarelim podatkom. | odluka 7, `reservations_page.dart` |
| Šta je „stara verzija aplikacije“? | Server pošalje kod koji aplikacija ne zna: dobija opštu poruku, ne pada. Nepoznato stanje/sport/uloga se preskače u listi. | `error_dto.dart` `isKnown`, `toDomainKnown` |
| Zašto jedan `domain` paket za sve? | Pravilo se piše jednom i ne mogu da se razilaze server i klijenti. Zato izmena roka menja ponašanje svuda. | odluka 2, tok 6 |

Odluke sa razlozima i **odbačenim mogućnostima** su u `docs/kt2-decisions.md`; komande za demonstraciju u `docs/kt2-odbrana.md`.
