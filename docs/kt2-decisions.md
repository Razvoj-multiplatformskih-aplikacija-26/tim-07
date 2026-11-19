# KT2 odluke

Ovaj dokument beleži odluke za KT2 (server, baza, ugovor, prijava i uloge) za glavni pojam sistema, **rezervaciju sportskog terena**. Za svaku odluku navedeno je obrazloženje i bar jedna odbačena mogućnost.

## Imena paketa i delova

| Deo | Putanja | Zavisi od |
| --- | ------- | --------- |
| Domenski paket | `packages/domain` | ništa (čist Dart) |
| Ugovor (DTO + JSON) | `packages/contract` | ništa (ne uvozi `domain`, Flutter ni `dart:io`) |
| Prevod ugovor ↔ domen | `packages/mapping` | `contract`, `domain` |
| HTTP klijent | `packages/api_client` | `contract`, `mapping`, `domain`, `package:http` |
| Bloc-ovi | `packages/blocs` | `domain` |
| Server | `apps/server` | `domain`, `contract`, `mapping`, Relic, PostgreSQL |

Server i klijenti koriste **isti** `domain` (pravila) i **isti** `mapping` (prevod), pa se pravilo i prevod pišu na jednom mestu.

---

## 1. Vrsta pravila: preklapanje u vremenu

**Odluka.** Glavno pravilo teme je zabrana vremenskog preklapanja. Dve rezervacije se preklapaju ako su na istom terenu, obe su aktivne (`pending` ili `confirmed`) i intervali `[početak, kraj)` im se seku (`doTimeRangesOverlap`). Isto važi za blokirane periode terena. Termin 14:00–16:00 i 16:00–18:00 se ne preklapaju.

Uz preklapanje važe i ostala pravila iz KT1: radno vreme, budućnost i ispravnost termina, rok za otkazivanje od 5 sati i dozvoljeni prelazi stanja.

**Obrazloženje.** Domen dozvoljava termine proizvoljnog trajanja (npr. 90 minuta), pa pravilo mora da radi nad intervalima, a ne nad unapred podeljenim slotovima.

**Odbačeno.** *Fiksni slotovi od po sat vremena sa jedinstvenim ključem (teren, početak) u bazi.* Bilo bi jednostavno za bazu, ali ne podržava termine od 90 minuta niti blokade koje počinju usred sata, a to već postoji u domenu iz KT1.

## 2. Ko konačno čuva pravilo: server uz zaštitu u bazi

**Odluka.** Konačnu odluku donosi **server**, pre svakog upisa, pozivom istih funkcija iz `domain` (`validateReservationSlot`, `validateCancellationBy`, `canTransitionReservationStatus`, `resolveReservationStatus`). Kada dva zahteva stignu u istom trenutku i oba prođu proveru u Dartu, **baza propušta samo jedan**: tabela `reservations` ima dva ograničenja isključivanja (PostgreSQL `EXCLUDE USING gist`, uz `btree_gist`):

- `reservations_no_double_booking`: isti teren i preklapanje `tstzrange(start_time, end_time)` za aktivne rezervacije (`pending`, `confirmed`);
- `reservations_one_field_per_user`: isti korisnik i preklapanje termina, i kada su tereni različiti.

Kada baza odbije upis (greška `23P01`), server vraća isto pravilo kao domen: `SlotAlreadyTaken`, na mreži `409 slot_taken`. Promena stanja je uslovni upis nad starim stanjem (`UPDATE … WHERE id = @id AND status = @from`): ako je neko u međuvremenu promenio rezervaciju, upis ne menja ništa i server vraća `409 invalid_status_transition`. Isto važi za odobravanje terena.

Izmena radnog vremena zaključava red terena (`SELECT … FOR UPDATE`), a stari raspored se briše i novi upisuje u jednoj transakciji. Pre upisa raspored proverava `validateFieldSchedule` iz domena, a neispravan raspored ostavlja stari netaknut.

Baza dodatno čuva ono što ume da izrazi: strani ključevi, `CHECK (start_time < end_time)`, `CHECK` nad dozvoljenim tekstom stanja, `CHECK (total_price >= 0)`.

Klijent proverava ista pravila nad podacima koje ima, samo da bi korisnik odmah video grešku. Klijent ne odlučuje.

**Obrazloženje.** Isto kao u primeru sa vežbi: pravilo piše domen, a baza garantuje da se ni pri istovremenim pozivima ne upišu dve aktivne rezervacije koje se preklapaju. Zaštita ne zavisi od toga da li neko kasnije u serveru zaboravi zaključavanje, a upisi za različite terene i korisnike idu paralelno.

**Odbačeno.**
- *Samo provera u klijentu.* Dva klijenta ne vide tuđe zahteve u istom trenutku, a poziv mimo aplikacije (curl) bi prošao.
- *MySQL i zaključavanje reda terena i korisnika (`SELECT … FOR UPDATE`).* Tako je bilo u prvoj verziji. Radi, ali zaštita postoji samo dok svaki upis u serveru zaključa prave redove istim redosledom; test sa paralelnim pozivima je u toj verziji otkrio da je zaključavanje samo terena propuštalo istog korisnika na dva terena. `EXCLUDE` u PostgreSQL-u to čuva u samoj bazi.
- *Okidač (trigger) u bazi koji odbija preklapanje.* Pravilo bi postojalo dvaput (SQL i Dart), greška iz okidača se teško prevodi u kod za klijenta, i teže je testirati.
- *Nivo izolacije `SERIALIZABLE` za celu bazu.* Radi, ali vraća greške serijalizacije koje bi server morao da ponavlja.

**Kako je provereno** (`apps/server/test/server_test.dart`, preko HTTP-a nad PostgreSQL-om):
- deset korisnika istovremeno traži isti termin istog terena: upisuje se tačno jedna rezervacija, ostalih devet dobija `409 slot_taken`;
- isti korisnik istovremeno traži isti sat na dva terena: prolazi jedna;
- dva vlasnika istovremeno potvrđuju i odbijaju istu rezervaciju: jedan uspe, drugi dobija `409 invalid_status_transition`.

## 3. Šta vidi zakasneli klijent

**Odluka.** Kada dva korisnika istovremeno traže isti termin, prvi dobija `201 Created`, a zakasneli dobija **`409 Conflict`** sa kodom `slot_taken`. Klijent prikazuje istu poruku kao kada pravilo proveri lokalno („Termin se preklapa sa postojećom rezervacijom.“) i ponovo učitava slobodne termine.

Isto važi za promenu stanja nad zastarelim podatkom: ako vlasnik potvrđuje rezervaciju koju je korisnik u međuvremenu otkazao, server proverava prelaz nad stanjem iz baze i vraća `409` sa kodom `invalid_status_transition`. Klijent osvežava zapis.

**Odbačeno.** *Poslednji upis pobeđuje (last write wins).* Tiho bi pregazio tuđu rezervaciju, a to tema izričito zabranjuje. *Lista čekanja za zauzet termin.* Nije deo zahteva teme i otvara nova stanja.

## 4. Šta koja uloga vidi

| Uloga | Rezervacije | Tereni |
| ----- | ----------- | ------ |
| bez prijave | ništa | aktivni i odobreni tereni, sportovi, slobodni termini |
| korisnik (`user`) | samo svoje | kao javnost |
| vlasnik (`owner`) | samo rezervacije na svojim terenima | svoji tereni (i neodobreni i neaktivni) + javni |
| administrator (`admin`) | sve | svi tereni, uključujući one koji čekaju odobrenje |

Filtriranje radi **server**, na osnovu identiteta iz tokena. Isti URL (`GET /reservations`) vraća različit skup u zavisnosti od toga ko pita. Korisnik koji traži tuđu rezervaciju po id-u dobija `404`, a ne `403`, da ne bi saznao da zapis postoji.

**Odbačeno.** *Server vraća sve, a klijent filtrira.* Podaci drugih korisnika bi stigli na uređaj i bili vidljivi svakome ko pogleda mrežni saobraćaj.

## 5. Format novca, vremena i stanja na mreži

| Podatak | Na mreži | Primer |
| ------- | -------- | ------ |
| Novac | ceo broj dinara (`int`) | `"pricePerHour": 3000` |
| Trenutak (početak, kraj, kreirano) | ISO-8601 u UTC, sa `Z` | `"startTime": "2026-11-12T17:00:00.000Z"` |
| Radno vreme | `"HH:mm"`, lokalno vreme objekta (Europe/Belgrade) | `"opensAt": "08:00"` |
| Datum za slobodne termine | `YYYY-MM-DD`, lokalni datum objekta | `?date=2026-11-12` |
| Stanje rezervacije | stabilan tekstualni kod | `"pending"`, `"confirmed"`, `"completed"`, `"cancelled"` |
| Sport, uloga | tekstualni kod | `"football"`, `"owner"` |
| Identifikator | ceo broj | `"id": 7` |

Nepoznat kod stanja (npr. server doda novo stanje, a aplikacija je starija) **ne obara klijent**: `contract` ga čuva kao nepoznatu vrednost, a klijent prikazuje opštu oznaku („Nepoznato stanje“) i ne nudi akcije.

U bazi: novac je `integer` (dinari), trenuci su `timestamptz`, stanja su `text` sa istim kodovima kao na mreži.

**Vremenska zona.** Radno vreme je lokalno, a trenuci su u UTC. Server radi u zoni `Europe/Belgrade` (`TZ` i podatak o zoni u Docker slici) i pre poziva pravila radnog vremena pretvara trenutke u lokalno vreme, tako da se pravilo iz `domain` ne menja.

**Odbačeno.**
- *Novac kao `double`.* Greške zaokruživanja (0,1 + 0,2), a dinari nemaju potrebu za decimalama.
- *Vreme kao broj milisekundi od 1970.* Nečitljivo u logu i curl odgovorima, a lako se pomeša sekunda i milisekunda.
- *Stanje kao indeks enuma (`0, 1, 2…`).* Promena redosleda u enumu bi tiho promenila značenje podataka.

## 6. Kako klijent traži deo velike liste

**Odluka.** Straničenje sa `limit` i `offset` u upitu, odgovor nosi i ukupan broj:

```
GET /fields?limit=20&offset=40&sport=tennis&city=Beograd
→ { "items": [...], "total": 87, "limit": 20, "offset": 40 }
```

Podrazumevano `limit=20`, najviše `100`. Redosled je stabilan (`ORDER BY` po polju i zatim po `id`), da se zapis ne pojavi na dve strane.

**Obrazloženje.** Backoffice tabela prikazuje broj strana i skače na stranu, za šta treba `total` i `offset`. Količina podataka u projektu je mala, pa nedostatak `offset`-a (sporiji na milionima redova) ovde ne smeta.

**Odbačeno.** *Kursor (`?after=<id>`).* Bolji za beskonačne liste i velike tabele, ali ne daje skok na stranu N i ukupan broj, a to backoffice traži.

## 7. Kako klijent saznaje za tuđu promenu

**Odluka.** Povlačenjem (*pull*): klijent ponovo učitava listu pri otvaranju ekrana, na „povuci za osvežavanje“ u mobilnoj aplikaciji i na `R` / dugme „Osveži“ u backoffice-u. Backoffice dodatno osvežava listu rezervacija na 30 sekundi dok je ekran otvoren. Posle svake akcije (potvrdi, odbij, otkaži) klijent koristi zapis koji je vratio server, a ne svoju pretpostavku.

Ako je zapis u međuvremenu promenjen, server to otkriva pri upisu (odluka 3) i klijent dobija `409`.

**Odbačeno.** *Server šalje promene (WebSocket ili Server-Sent Events).* Brže, ali zahteva stalnu vezu, ponovno povezivanje i stanje na serveru. Za KT2 je povlačenje dovoljno, a ispravnost i dalje čuva server.

## 8. Šta je javno bez prijave

Bez tokena rade samo čitanja kataloga:

- `GET /health`
- `GET /fields`, `GET /fields/:id` (samo aktivni i odobreni tereni)
- `GET /sports` (sportovi koji postoje na aktivnim terenima)
- `GET /fields/:id/availability?date=` (slobodni termini, bez podataka o tome **ko** je rezervisao)
- `POST /auth/login`

Sve ostalo traži `Authorization: Bearer <token>`. Bez tokena odgovor je `401` sa kodom `unauthenticated`.

**Odbačeno.** *Sve iza prijave.* U suprotnosti sa zahtevom 6 (javni katalog i indeksiranje pretraživača u KT4).

## 9. Ko sme da menja tuđi zapis i u kojim stanjima

| Akcija | Ko | Stanje pre | Dodatni uslov |
| ------ | -- | ---------- | ------------- |
| Kreiranje rezervacije | korisnik | — | sva pravila iz odluke 1 |
| Otkazivanje | korisnik, samo **svoje** | `pending`, `confirmed` | najkasnije 5 h pre početka |
| Check-in | korisnik, samo svoje | `confirmed` | od 24 do 5 h pre početka |
| Potvrda | vlasnik **tog terena** | `pending` | pre roka od 5 h |
| Odbijanje (→ `cancelled`) | vlasnik tog terena | `pending` | — |
| Otkazivanje od strane vlasnika | vlasnik tog terena | `confirmed` | pre početka termina |
| Otkazivanje od strane admina | administrator | `pending`, `confirmed` | rešavanje prijavljenih nepravilnosti |
| Izmena terena, cene, radnog vremena, blokada | vlasnik **tog terena** | — | — |
| Odobravanje objekta | administrator | teren čeka odobrenje | — |

**Odobravanje terena.** Teren ima stanje odobrenosti `pending` → `approved` ili `rejected`. Nov teren ulazi kao `pending` i javno je vidljiv (i može da se rezerviše) samo kada je aktivan i `approved` (`isFieldPublic` u domenu). Odbijanje čuva razlog. Kada vlasnik izmeni odbijen teren, teren ponovo čeka odobrenje (`approvalStatusAfterOwnerEdit`); izmena podataka nikad ne može sama da odobri teren. Administrator može i da povuče odobrenje (`approved` → `rejected`) kada rešava prijavljenu nepravilnost. Prelaze određuje `canTransitionApprovalStatus`, a server upis radi uz uslov na staro stanje, pa od dve istovremene odluke prolazi jedna.

`completed` i `cancelled` su konačna stanja: niko ih ne menja. Korisnik nikad ne potvrđuje ni odbija. Vlasnik ne dira rezervacije ni terene drugog vlasnika. Zabranjena akcija daje `403` sa kodom `forbidden`.

Prava se pišu **jednom**, u `domain` (`canConfirmReservation`, `canCancelReservation(user, reservation, field)`, `canManageField(user, field)` …). Klijenti ih koriste da sakriju dugmad, a server da odbije poziv. Funkcije su u `packages/domain/lib/src/rules/permissions.dart` (T45): `canCreateReservation`, `canViewReservation`, `canConfirmReservation`, `canRejectReservation`, `canCancelReservation`, `canCheckInReservation`, `allowedReservationActions` (za dugmad), `canViewField`, `canCreateField`, `canManageField`, `canReviewField`, `canViewStatistics`, `canManageUsers` i `canSignIn(uloga, aplikacija)`. Odgovor „ne“: korisnik koji traži tuđu rezervaciju (`canViewReservation` je false) dobija 404, zabranjena akcija nad zapisom koji sme da vidi dobija 403. Test u `domain` pada ako server ili aplikacija sami porede ulogu. Prijavu u aplikacijama vodi zajednički `AuthBloc` (T48, `packages/blocs`) nad portom `AuthRepository` iz `domain`: u njemu `canSignIn(uloga, aplikacija)` odbija nalog koji nije za tu aplikaciju („Backoffice je za vlasnike i administratore sportskih objekata.“), a istek prijave vraća korisnika na prijavu uz poruku.

**Odbačeno.** *Provere uloga u svakom ekranu i u svakoj ruti servera posebno.* Pravila bi se razišla, pa bi aplikacija nudila akciju koju server odbija (ili obrnuto).

## 10. Šta pregledač ne dozvoljava (CORS)

Backoffice u pregledaču radi na drugom poreklu (npr. `http://localhost:5000`) od servera (`http://localhost:8080`). Pregledač tada blokira odgovore servera ako server izričito ne dozvoli to poreklo, a pre zahteva sa `Authorization` zaglavljem ili `Content-Type: application/json` šalje *preflight* `OPTIONS`.

**Odluka.**
- Server odgovara na `OPTIONS` i dodaje `Access-Control-Allow-Origin` samo za porekla iz `CORS_ALLOWED_ORIGINS` u `.env` (u razvoju svaki `http://localhost:*`).
- Dozvoljena zaglavlja: `Authorization`, `Content-Type`. Dozvoljene metode: `GET, POST, PATCH, PUT, DELETE, OPTIONS`.
- Token ide u zaglavlju `Authorization`, **ne u kolačiću**, pa nema CSRF napada i ne treba `Access-Control-Allow-Credentials`.
- `api_client` koristi `package:http` (bez `dart:io`), pa isti kod radi i u pregledaču.

Mobilna i desktop aplikacija ne podležu CORS-u, ali dobijaju ista zaglavlja.

**Odbačeno.** *`Access-Control-Allow-Origin: *`.* Svaki sajt bi mogao da šalje zahteve u ime prijavljenog korisnika čiji token pročita. *Posrednik (proxy) koji servira backoffice i API sa istog porekla.* Uklanja CORS, ali dodaje još jedan servis u Docker Compose samo zbog razvoja.

## 11. Prijava i token

**Odluka.**
- Lozinke se čuvaju kao **Argon2id** heš (parametri OWASP: 19 MiB memorije, 2 prolaza) sa nasumičnom solju po korisniku, u PHC formatu (`$argon2id$v=19$m=19456,t=2,p=1$<so>$<heš>`). Format nosi parametre, pa se kasnije mogu pojačati bez promene šeme. Računa se u posebnom isolate-u, da ne blokira druge zahteve. Isto kao u primeru Rafstoran.
- `POST /auth/login` vraća potpisan **JWT (HS256)** sa `sub` (id korisnika), `role` i `exp`. Tajna i trajanje su u `.env` (`JWT_SECRET`, `JWT_TTL_MINUTES`).
- Middleware proverava potpis i istek pri svakom pozivu. Istekao token → `401` sa kodom `token_expired`, lažan ili izmenjen → `401` sa kodom `invalid_token`.
- Identitet se uzima **samo iz tokena**. Polje `userId` u telu zahteva se ignoriše.
- Pogrešna lozinka i nepostojeći e-mail daju istu grešku (`invalid_credentials`) i traju isto (i za nepostojeći nalog proverava se heš), da se ne otkrije koji nalozi postoje.
- Odjava ne treba poziv servera: token se ne čuva na serveru, pa ga klijent briše iz skladišta, a server ga odbija kada istekne.
- Token se čuva iza porta `SessionStore` (T49, `packages/session_storage`): u bezbednom skladištu platforme (Keystore, Keychain, Credential Manager, libsecret), a na vebu u `localStorage`, jer mora da preživi osvežavanje stranice. To je slabije od skladišta platforme (skripta sa iste adrese ga može pročitati), pa token ističe i na serveru. Lozinka se na uređaju ne čuva. **Odbačeno:** `sessionStorage` (nestaje sa zatvaranjem taba) i kolačić (CSRF i `Access-Control-Allow-Credentials`).

**Odbačeno.**
- *Sesije u bazi (nasumičan id u tabeli).* Lako se poništavaju, ali svaki poziv čita bazu. JWT je dovoljan za KT2, a poništavanje se ostvaruje kratkim trajanjem.
- *PBKDF2-HMAC-SHA256.* Takođe dozvoljen, ali troši samo procesor, pa ga grafičke kartice napadaju mnogo brže nego Argon2id, koji troši i memoriju.
- *SHA-256 bez soli i iteracija.* Prebrzo za napad grubom silom i iste lozinke daju isti heš.
- *Ista greška za istekao i lažan token.* Jednostavnije, ali klijent tada ne može da kaže korisniku „prijava je istekla“, pa su kodovi odvojeni.

## 12. Spoljni servis iza porta

**Odluka.** Spoljni servis teme je **slanje obaveštenja korisniku** (e-pošta / push) kada vlasnik potvrdi ili odbije rezervaciju. Server ga poziva kroz port `NotificationGateway`. Za KT2 implementacija je `FakeNotificationGateway`, koja upisuje poruku u log. Ključ servisa (`NOTIFICATION_API_KEY`) postoji samo u `.env` servera.

Pad servisa ne poništava potvrdu: rezervacija se prvo upiše (transakcija se završi), pa se zatim šalje obaveštenje, a greška slanja se samo zapiše u log. Slanje ima vremensko ograničenje od 5 sekundi, pa servis koji ne odgovara ne zadržava odgovor vlasniku. Bez ključa obaveštenje se ne šalje, a potvrda i dalje prolazi.

Potvrda i odbijanje važe samo za rezervaciju **na čekanju**, a upis je uslovljen tim stanjem, pa vlasnik ne može da „odbije“ rezervaciju koja je u međuvremenu potvrđena. Razlog odbijanja se čuva u `cancellation_reason`.

**Odbačeno.**
- *Klijent sam šalje e-poštu preko servisa.* Ključ bi morao da bude u aplikaciji, pa bi ga svako mogao izvući iz APK-a ili iz JavaScript-a u pregledaču.
- *Slanje unutar transakcije, pa poništavanje potvrde ako slanje ne uspe.* Spor ili nedostupan servis bi držao otvorenu transakciju i obarao potvrde, a obaveštenje je sporedno u odnosu na samu rezervaciju.

## 13. Greške na mreži

Server nikad ne šalje gotovu poruku za korisnika, već **kod i podatke**:

```json
{ "error": { "code": "cancellation_deadline_expired", "details": { "hours": 5 } } }
```

| HTTP | Kod | Domenska greška |
| ---- | --- | --------------- |
| 400 | `bad_request` | neispravan JSON ili parametar |
| 401 | `unauthenticated`, `invalid_token`, `token_expired`, `invalid_credentials` | — |
| 403 | `forbidden` | prava iz odluke 9 |
| 403 | `account_deactivated` | — (odluka 20) |
| 404 | `not_found` | — |
| 409 | `slot_taken` | `SlotAlreadyTaken` |
| 409 | `invalid_status_transition` | `InvalidReservationStatus` |
| 409 | `invalid_approval_transition` | `ApprovalTransitionNotAllowed` |
| 409 | `block_overlaps_reservation` | `BlockOverlapsConfirmedReservation` (odluka 15) |
| 422 | `invalid_block_range`, `block_in_past` | `InvalidBlockRange`, `BlockInPast` |
| 422 | `invalid_time_range` | `InvalidTimeRange` |
| 422 | `reservation_in_past` | `ReservationInPast` |
| 422 | `outside_working_hours` | `OutsideWorkingHours` |
| 422 | `field_blocked` | `FieldBlocked` |
| 422 | `cancellation_deadline_expired` (`hours`) | `CancellationDeadlineExpired` |
| 422 | `check_in_not_allowed` (`opensHours`, `closesHours`) | `CheckInNotAllowed` |
| 422 | `invalid_duration` | `InvalidReservationDuration` |
| 500 | `internal` | neočekivana greška (detalji samo u logu servera) |

Poruku na srpskom pravi klijent iz koda, istom funkcijom kao kada pravilo proveri lokalno. Nepoznat kod daje opštu poruku („Došlo je do greške. Pokušajte ponovo.“). Konkretan oblik DTO-a definiše `packages/contract` (T40), a prevod `packages/mapping` (T41). Poruke na srpskom pravi `packages/messages` (T42): jedna funkcija `errorMessage(ErrorDto)` koju koristi i lokalna provera pravila (`validationMessage`) i greška sa servera, pa korisnik vidi istu poruku. Broj sati u poruci dolazi iz `details`, ne iz aplikacije, pa server koji promeni rok menja poruku bez nove verzije aplikacije. HTTP repozitorijume pišu `packages/api_client` (T43): isti kod na VM-u i u pregledaču, sve greške stižu kao `ServerRejectedException` ili `ServerUnreachableException`.

**Odbačeno.** *Server šalje gotovu poruku na srpskom.* Jednostavnije za klijenta, ali server tada zna jezik i tekst svih ekrana, stara verzija aplikacije prikazuje tekst koji ne odgovara njenom ekranu, a ista greška bi izgledala drugačije kada je pravilo proverio klijent. *HTTP status kao jedini nosilac greške.* `409` ne kaže da li je termin zauzet ili je promenjeno stanje, pa klijent ne bi umeo da izabere poruku.

## 14. Statistika zauzetosti

**Odluka.** Zauzetost računa **server**, jednom funkcijom iz domena (`calculateOccupancyReport`), za izabrani period: nedelja (od ponedeljka u ponoć) ili mesec, po lokalnom vremenu objekta.

- **Raspoloživo vreme** terena je zbir radnog vremena po danima u periodu, bez blokiranih perioda.
- **Zauzeto vreme** su rezervacije koje nisu otkazane (na čekanju, potvrđene, završene), i to samo deo koji pada u raspoloživo vreme. Zato zauzetost nikad ne prelazi 100 %, a rezervacija preko granice perioda računa se samo unutar perioda.
- **Realizovane** su završene rezervacije koje počinju u periodu, a **otkazane** su otkazane i odbijene zajedno (u bazi su obe u stanju `cancelled`).
- Stanja se pre računanja osvežavaju sa `resolveReservationStatus`, pa se potvrđena rezervacija sa dolaskom čiji je termin prošao računa kao završena i kada baza to još nije upisala.
- Vlasnik dobija statistiku samo za svoje terene, a administrator za sve.
- Na mreži idu minuti (celi brojevi), a procenat zaokružuje klijent iz njih, isto kao `occupancyPercent` u domenu.

**Odbačeno.**
- *Računanje u klijentu.* Klijent bi morao da preuzme sve rezervacije svih terena za ceo period, uključujući tuđe podatke, samo da bi prikazao nekoliko brojeva.
- *Ceo proračun u jednom SQL upitu.* Radno vreme po danima, blokade i rezervacije preko granice perioda teško se izražavaju u SQL-u, a pravilo bi postojalo i u SQL-u i u domenu. Ovako je ista funkcija proverena unit testovima bez baze.

## 15. Blokiranje termina

Vlasnik blokira deo terena (održavanje, događaj). Blokada je zapis sa terenom, početkom, krajem i razlogom, i ima `id` da bi mogla da se ukloni.

- Pravilo je u `validateBlockedPeriod` (domen), a izvršavaju ga isto server (`PostgresTerenzo`) i lažni izvor (`FakeFieldScheduleRepository`). Tri razloga odbijanja: kraj nije posle početka (`invalid_block_range`), blokada je cela u prošlosti (`block_in_past`) i preklapa se sa potvrđenom rezervacijom (`block_overlaps_reservation`).
- Blokadu sprečava samo **potvrđena** rezervacija. Rezervaciju na čekanju vlasnik može da odbije, pa ne sme da zaključa blokadu. Potvrđena rezervacija kojoj je istekao rok se računa kao otkazana (`resolveReservationStatus`), isto kao u proveri slobodnih termina.
- Server upisuje blokadu u transakciji i prvo zaključa red terena (`FOR UPDATE`), isto kao pri pravljenju rezervacije. Zato istovremena blokada i rezervacija ne mogu obe da uspeju; test pokreće obe i traži tačno jedan uspeh.
- Obe strane, rezervacija i blokada, koriste isto pravilo: posle blokade `validateReservationSlot` vraća `FieldBlocked`, pa mobilna aplikacija termin ne nudi (preko `calculateAvailability`).
- Vlasnik blokira samo svoje terene (`canManageField`). `BlockedPeriodsBloc` ne nudi tuđe terene, a ako ipak stigne zahtev za tuđi teren, odgovor je zabranjeno.
- Posle svakog odbijanja Bloc ponovo učitava spisak, jer je odbijanje najčešće znak da se nešto promenilo na serveru.
- Putanja za uklanjanje je `DELETE /fields/:id/blocked-periods/:blockId`. Server proverava da blokada pripada tom terenu, inače je „nije pronađeno“.

**Odbačeno.**
- *Blokada preko potvrđene rezervacije koja otkazuje rezervaciju.* Korisnik bi izgubio termin bez svoje volje. Vlasnik prvo otkaže rezervaciju (sa razlogom), pa tek onda blokira.
- *Provera samo u klijentu.* Dva vlasnika ili vlasnik i korisnik mogu istovremeno da menjaju isti teren, pa konačnu reč ima server.

## 16. Baza, migracije i početni podaci

**Odluka.** Kao u primeru sa vežbi:
- baza je **PostgreSQL 17**, a `compose.yaml` podiže servise `db`, `migrate` i `server` (i `adminer` uz `--profile tools`);
- šema je u `apps/server/migrations` u formatu alata **dbmate** (`-- migrate:up` / `-- migrate:down`), a servis `migrate` je primeni pa izađe; server kreće tek kada migracije uspeju;
- početne podatke upisuje server kada je baza prazna (`seed.dart`): 11 rezervacija u sva četiri stanja, nalog za svaku ulogu i tri korisnika mobilne aplikacije, sa lozinkom iz `DEMO_PASSWORD` (u bazi samo Argon2id heš);
- server se gradi u slici `dart:3.13.5`, a radi u praznoj slici (`scratch`) kao korisnik bez administratorskih prava.

**Odbačeno.**
- *MySQL sa pokretačem migracija u samom serveru.* Prva verzija. Server je morao da zna redosled i istoriju migracija i da ih štiti od dva istovremena pokretanja; dbmate to već radi i odvaja šemu od koda servera.
- *Početni podaci kao SQL migracija.* Datumi bi bili fiksni i zastareli bi posle nekoliko dana; seed u serveru pravi termine u odnosu na trenutni datum.


## 17. Kalendar rezervacija

Vlasnik vidi dan ili nedelju svojih terena, termin po termin.

- Redove kalendara računa domen (`buildFieldCalendarDay`) iz radnog vremena terena, rezervacija i blokada. Isto radno vreme koristi `calculateAvailability`, pa kalendar i aplikacija za korisnike ne prikazuju različite termine. `CalendarBloc` samo učitava podatke i drži opseg.
- **Dnevni prikaz:** kolona po terenu za izabrani dan. **Nedeljni prikaz:** kolona po danu (od ponedeljka) za jedan teren koji vlasnik bira. Svi tereni u sedam kolona bi bili previše za uski prozor, a vlasnik pregleda nedelju jednog terena odjednom.
- Redovi: slobodno, prošlo (slobodan termin koji je već počeo), na čekanju, potvrđena, završena i blokirano. Svaki red ima i ikonu i tekst stanja, a legenda ih objašnjava; boja nije jedini nosilac značenja.
- Otkazana rezervacija nije u kalendaru: njen termin je slobodan. To važi i za rezervaciju koja je automatski otkazana (`resolveReservationStatus`): na čekanju kojoj je istekao rok, ili potvrđenu bez check-in-a posle roka. Kalendar zato ne pravi izuzetak od pravila koje važi na serveru.
- Rezervacija i blokada koje se preklapaju (moguće samo za rezervaciju na čekanju) se prikazuju obe; termin pripada rezervaciji, da je vlasnik vidi i može da je odbije.
- Pomeranje menja opseg odmah (naslov i dugmad ostaju na mestu, a kolone čekaju učitavanje), a zastareo odgovor se odbacuje. Osvežavanje istog opsega zadržava stare kolone dok nove ne stignu. Greška pri učitavanju opsega zadržava novi naslov i nudi „Pokušaj ponovo“.
- Klik ili Enter na rezervaciju otvara iste detalje i akcije kao tabela (`ReservationDetailsPanel`). Posle potvrde ili otkazivanja `ReservationBloc` javlja da je gotov, pa se kalendar osvežava. U uskom prozoru detalji zamenjuju kalendar uz „Nazad na kalendar“.
- Tastatura: strelice levo i desno pomeraju opseg, `T` vraća na danas, a rezervacije su u redosledu za Tab.

**Odbačeno.**
- *Mreža sa satnicom (visina reda prema trajanju).* Lepša je na velikom ekranu, ali loše se prilagođava uskom prozoru i čitaču ekrana. Lista termina po koloni radi svuda, a rezervacija od više sati je jedan red sa svojim opsegom.
- *Svi tereni u nedeljnom prikazu.* Vidi gore.

## 18. Gde je Bloc, a gde lokalno stanje (backoffice)

**Odluka.** Bloc postoji tamo gde stanje dolazi sa servera ili ga deli više ekrana; sve ostalo je stanje widgeta.

- **Deljeni Bloc-ovi u `packages/blocs`, po oblastima** (`auth`, `reservations`, `reservation_list`, `users`, `fields`, `field_management`, `field_review`, `blocked_periods`, `calendar`, `statistics`, …). Svaki radi samo preko portova iz domena, pa ga isto koriste mobilna aplikacija, backoffice i testovi sa lažnim repozitorijumima. `AuthBloc` i `ReservationBloc` koriste oba klijenta.
- **U backoffice-u ostaju samo dva lokalna:** `ReservationSelectionBloc` (koja je rezervacija izabrana, deli ga tabela, lista, panel i tastatura) i `DirectoryCubit` (imena terena za tabelu, učitana sa servera posle prijave). Ne trebaju mobilnoj aplikaciji, pa nisu u zajedničkom paketu.
- **Bez Bloc-a:** izabrana sekcija u navigaciji, otvoren dijalog, polja forme pre slanja i radno vreme pre čuvanja. To je stanje jednog widgeta; Bloc dobija tek gotov zahtev (`FieldSaveRequested`, `FieldScheduleSaveRequested`, `FieldReviewDecided`).
- Nijedan widget ne čita `BackofficeDemoData`; demo podaci su samo izvor za lažne repozitorijume u testovima i demo režimu.

**Odbačeno.** *Bloc za svaku stranicu i svaki dijalog.* Više koda bez koristi: stanje koje vidi samo jedan widget ne treba da prolazi kroz događaje i stanja, a teže se prati na odbrani.

## 19. Tabela rezervacija: filteri, pretraga, sortiranje i strane

Vlasnik filtrira rezervacije po terenu, stanju i datumu, traži po korisniku, sortira po koloni i lista po stranama. Sve to radi izvor podataka; tabela traži samo stranu koju prikazuje.

- **Jedan upit, jedno pravilo.** `ReservationQuery` (domen) nosi filtere, pretragu, sortiranje i stranu, a `searchReservations` (domen) ga primenjuje: filteri se spajaju sa „i“, datumi se odnose na dan početka rezervacije (oba kraja uključena), pretraga traži svaku reč u imenu ili email-u korisnika bez razlike u slovima i dijakriticima (`petrovic` nalazi „Petrović“), a sortiranje je stabilno (pri jednakim vrednostima ide po `id`, pa se rezervacija ne pojavi na dve strane). Pravilo koriste server (`GET /reservations`) i lažni izvor u klijentu, pa daju iste strane za iste podatke.
- **Mreža:** `GET /reservations?fieldId=&status=&from=yyyy-MM-dd&to=yyyy-MM-dd&search=&sort=&order=&limit=&offset=`. `sort` je jedan od `id`, `field`, `user`, `start`, `status`, a `order` je `asc` ili `desc`. Nepoznata vrednost je 400. Odgovor je strana iz odluke 6 sa ukupnim brojem.
- **Port:** `ReservationSearchRepository` (domen), odvojen od `ReservationRepository`, da postojeće implementacije i testovi ostanu isti. `HttpReservationRepository` i `FakeReservationRepository` implementiraju oba.
- **`ReservationListBloc`** drži upit u svakom stanju (Loading, Loaded, Empty, NoMatches, Error), pa greška ili učitavanje ne brišu izabrane filtere. Razlikuje „nema nijedne rezervacije“ (Empty) od „filteri ništa ne nalaze“ (NoMatches): drugo nije greška i nudi „Poništi filtere“. Pretraga čeka da vlasnik prestane da kuca (300 ms), a odgovor starijeg zahteva se odbacuje. Svaka promena filtera, pretrage ili sortiranja vraća na prvu stranu. Ako strana nestane posle osvežavanja (poslednja rezervacija sa nje je otkazana), prikazuje se poslednja koja postoji.
- **Izbor:** `ReservationSelectionBloc` ostaje lokalni. Izabrana rezervacija ostaje izabrana dok je na strani koja se prikazuje, a kada je filter, pretraga ili strana izbace, izbor se briše. Dok se nova strana učitava, izbor se ne dira.
- **`ReservationBloc` ostaje za akcije** (potvrda, otkazivanje). Kada akcija završi, tabela se osvežava, jer stanje rezervacije možda više ne odgovara filteru.
- **Tastatura:** strelice, Home i End kreću se po redovima trenutne strane, a PgUp i PgDn menjaju stranu. Jednoslovne prečice (P, O, R) ne važe dok je fokus u polju pretrage.

**Odbačeno.**
- *Filtriranje u klijentu nad celom listom.* Radi dok ima malo podataka, ali tabela bi učitavala sve rezervacije svih terena, a odluka 6 traži strane sa servera.
- *Kursor umesto `offset`.* Vidi odluku 6.

## 20. Nalozi: pregled i deaktivacija (administrator)

Administrator vidi sve naloge, traži ih, filtrira po ulozi i deaktivira ih.

- **Prava u domenu.** `canManageUsers` (samo administrator) i `canDeactivateUser(actor, target)`: administrator menja tuđ nalog, ne svoj, jer bi ostao bez pristupa, a možda i jedini administrator. Isto pravilo proverava `UsersBloc` (da uopšte ne traži tuđe podatke) i server (konačna reč). Vlasnik nema stavku „Korisnici“ u meniju, a server mu na `GET /users` i `PATCH /users/:id` odgovara sa 403.
- **Deaktivacija je stanje naloga (`AppUser.isActive`), ne brisanje.** Rezervacije i istorija ostaju vezani za nalog, a nalog može ponovo da se aktivira. Kolona `users.is_active` (nova migracija) je podrazumevano `true`, pa postojeći nalozi ostaju aktivni.
- **Prijava.** Deaktiviran nalog dobija `403 account_deactivated` pri prijavi, ali tek kada je lozinka tačna; pogrešna lozinka i dalje daje `401 invalid_credentials`, da se tuđim pogađanjem ne sazna koji nalozi su deaktivirani. Poruka je „Nalog je deaktiviran. Obratite se administratoru.“.
- **Postojeća prijava prestaje odmah.** Server pri svakom zahtevu proverava nalog iz tokena, pa deaktiviran korisnik ne može da nastavi sa starim tokenom do isteka. Taj odgovor je `403 account_deactivated`, isti kao pri prijavi; klijent tada briše sačuvanu prijavu i vraća korisnika na prijavu, gde ga čeka ista poruka.
- **Mreža:** `PATCH /users/:id` sa telom `{"isActive": false}` vraća nalog posle izmene. Spisak (`GET /users`) sada nosi i `isActive`, samo za administratora.
- **Pretraga i uloga rade u klijentu** (`filterUsers`, domen) nad celim spiskom, za razliku od tabele rezervacija (odluka 19). Naloga ima malo (stotine, ne hiljade), a pretraga je tada trenutna i bez zahteva po slovu. Ako broj naloga naraste, ista funkcija prelazi na server kao `searchReservations`.
- **Prikaz:** tabela sa kolonama korisnik (ime i email), uloga, datum registracije, stanje i akcija. Stanje je i ikona i reč, ne samo boja. U uskom prozoru nalozi su kartice. Deaktivacija traži potvrdu, aktivacija ne.

**Odbačeno.**
- *Brisanje naloga.* Rezervacije imaju strani ključ na korisnika, a brisanje bi izgubilo istoriju koja je potrebna statistici.
- *Deaktivacija samo zabranjuje novu prijavu.* Korisnik bi mogao da nastavi sa starim tokenom do isteka (do 8 sati), što nije ono što administrator traži.

## 21. Ko je rezervisao: podaci uz rezervaciju za osoblje terena

Vlasnik terena mora da zna ko je rezervisao (ime i kontakt), a ne sme da čita tuđe naloge (`GET /users` je samo za administratora, odluka 20).

- **Odluka.** Server uz rezervaciju šalje i `customer` (ime, email, telefon, bez datuma rođenja) kada je čita neko ko nije sam rezervisao: vlasnik tog terena ili administrator. Korisnik svoju rezervaciju dobija bez tog bloka. `Reservation.customer` (domen) je zato opcioni.
- **Obrazloženje.** Podaci o korisniku idu samo uz rezervaciju koju osoblje ionako sme da vidi (`canViewReservation`), pa vlasnik ne dobija ništa o ljudima koji nisu rezervisali njegove terene. Odvojen spisak naloga za vlasnika bi tražio svoje pravilo i svoju rutu.
- **Klijent** piše ime iz `reservation.customer`; kada ga nema, „Korisnik #id“. Ime se nikad ne uzima iz demo podataka kada postoji server.
- Pretraga po korisniku u tabeli rezervacija (odluka 19) računa se na serveru nad istim nalozima.

**Odbačeno.** *`GET /users/:id` za vlasnika.* Dodatan zahtev po rezervaciji (ili keš imenika) za podatak koji server već ima u istom upitu.
