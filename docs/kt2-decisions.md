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
| Server | `apps/server` | `domain`, `contract`, `mapping`, Relic, MySQL |

Server i klijenti koriste **isti** `domain` (pravila) i **isti** `mapping` (prevod), pa se pravilo i prevod pišu na jednom mestu.

---

## 1. Vrsta pravila: preklapanje u vremenu

**Odluka.** Glavno pravilo teme je zabrana vremenskog preklapanja. Dve rezervacije se preklapaju ako su na istom terenu, obe su aktivne (`pending` ili `confirmed`) i intervali `[početak, kraj)` im se seku (`doTimeRangesOverlap`). Isto važi za blokirane periode terena. Termin 14:00–16:00 i 16:00–18:00 se ne preklapaju.

Uz preklapanje važe i ostala pravila iz KT1: radno vreme, budućnost i ispravnost termina, rok za otkazivanje od 5 sati i dozvoljeni prelazi stanja.

**Obrazloženje.** Domen dozvoljava termine proizvoljnog trajanja (npr. 90 minuta), pa pravilo mora da radi nad intervalima, a ne nad unapred podeljenim slotovima.

**Odbačeno.** *Fiksni slotovi od po sat vremena sa jedinstvenim ključem (teren, početak) u bazi.* Bilo bi jednostavno za bazu, ali ne podržava termine od 90 minuta niti blokade koje počinju usred sata, a to već postoji u domenu iz KT1.

## 2. Ko konačno čuva pravilo: server uz zaštitu u bazi

**Odluka.** Konačnu odluku donosi **server**, pre svakog upisa, pozivom istih funkcija iz `domain` (`validateReservationSlot`, `validateCancellation`, `canTransitionReservationStatus`, `resolveReservationStatus`). Provera i upis su u **jednoj transakciji** koja **prvo** zaključa red terena i red korisnika (`SELECT id … FOR UPDATE`), a tek onda čita rezervacije, radno vreme i blokade. Drugi zahtev za isti teren (ili istog korisnika, jer korisnik ne sme da ima dve rezervacije u isto vreme ni na različitim terenima) čeka da se prva transakcija završi, pa tek onda čita rezervacije i vidi novi upis. Zaključavanje uvek ide istim redom (teren, pa korisnik), pa dve transakcije ne mogu da čekaju jedna drugu u krug (deadlock).

Izmena radnog vremena zaključava isti red terena, a stari raspored se briše i novi upisuje u jednoj transakciji. Rezervacija koja stigne u isto vreme zato se proverava ili po starom ili po novom rasporedu, nikad po delimično upisanom. Pre upisa raspored proverava `validateFieldSchedule` iz domena (otvaranje pre zatvaranja, ispravno vreme, jedan red po danu), a neispravan raspored ostavlja stari netaknut.

Transakcije rade u nivou izolacije `READ COMMITTED`: svaka naredba vidi poslednje potvrđene podatke. U podrazumevanom `REPEATABLE READ` transakcija čita sliku baze napravljenu pri prvom običnom čitanju, pa bi čitanje pre zaključavanja dalo staru sliku bez tuđe rezervacije.

Baza dodatno čuva ono što ume da izrazi: strani ključevi, `CHECK (start_time < end_time)`, `CHECK` nad dozvoljenim tekstom stanja, `CHECK (price >= 0)`.

Klijent proverava ista pravila nad podacima koje ima, samo da bi korisnik odmah video grešku. Klijent ne odlučuje.

**Obrazloženje.** MySQL nema ograničenje isključivanja za intervale (kao `EXCLUDE` u PostgreSQL-u), pa preklapanje ne može da se izrazi kao `UNIQUE`. Zaključavanje reda terena serijalizuje samo upise za **isti teren**, a upisi za druge terene idu paralelno.

**Odbačeno.**
- *Samo provera u klijentu.* Dva klijenta ne vide tuđe zahteve u istom trenutku, a poziv mimo aplikacije (curl) bi prošao.
- *Okidač (trigger) u bazi koji odbija preklapanje.* Pravilo bi postojalo dvaput (SQL i Dart), greška iz okidača se teško prevodi u kod za klijenta, i teže je testirati.
- *Nivo izolacije `SERIALIZABLE` za celu bazu.* Radi, ali zaključava šire nego što treba i vraća deadlock greške koje bi server morao da ponavlja.
- *Zaključati samo teren.* Tako je bilo u prvoj verziji, i test sa paralelnim pozivima je pokazao da isti korisnik istovremeno dobija dve rezervacije u isto vreme na dva terena.

**Kako je provereno** (`apps/server/test/concurrency_test.dart`, nad pravim MySQL-om):
- 12 korisnika istovremeno traži isti termin istog terena: upisuje se tačno jedna rezervacija, ostalih 11 dobija `SlotAlreadyTaken` (na mreži `409 slot_taken`), nijedan ne dobija neočekivanu grešku.
- 12 istovremenih termina koji se samo delimično preklapaju: prolazi jedan.
- Isti termin na dva različita terena: prolaze oba (zaključavanje ne usporava nepovezane upise).
- Isti korisnik istovremeno na dva terena u isto vreme: prolazi jedan.
- Otkazivanje i potvrda iste rezervacije istovremeno: stanje u bazi odgovara ishodu koji su klijenti dobili.

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

U bazi: novac je `INT` (dinari), trenuci su `DATETIME` u UTC, stanja su `VARCHAR` sa istim kodovima kao na mreži.

**Vremenska zona.** Radno vreme je lokalno, a trenuci su u UTC. Server radi u zoni `Europe/Belgrade` (`TZ` u kontejneru) i pre poziva pravila radnog vremena pretvara trenutke u lokalno vreme, tako da se pravilo iz `domain` ne menja.

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

Prava se pišu **jednom**, u `domain` (`canConfirmReservation`, `canCancelReservation(user, reservation, field)`, `canManageField(user, field)` …). Klijenti ih koriste da sakriju dugmad, a server da odbije poziv.

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

**Odbačeno.**
- *Sesije u bazi (nasumičan id u tabeli).* Lako se poništavaju, ali svaki poziv čita bazu. JWT je dovoljan za KT2, a poništavanje se ostvaruje kratkim trajanjem.
- *PBKDF2-HMAC-SHA256.* Takođe dozvoljen, ali troši samo procesor, pa ga grafičke kartice napadaju mnogo brže nego Argon2id, koji troši i memoriju.
- *SHA-256 bez soli i iteracija.* Prebrzo za napad grubom silom i iste lozinke daju isti heš.
- *Ista greška za istekao i lažan token.* Jednostavnije, ali klijent tada ne može da kaže korisniku „prijava je istekla“, pa su kodovi odvojeni.

## 12. Spoljni servis iza porta

**Odluka.** Spoljni servis teme je **slanje obaveštenja korisniku** (e-pošta / push) kada vlasnik potvrdi ili odbije rezervaciju. Server ga poziva kroz port `NotificationGateway`. Za KT2 implementacija je `FakeNotificationGateway`, koja upisuje poruku u log. Ključ servisa (`NOTIFICATION_API_KEY`) postoji samo u `.env` servera.

Pad servisa ne poništava potvrdu: rezervacija se prvo upiše (transakcija se završi), pa se zatim šalje obaveštenje, a greška slanja se samo zapiše u log. Slanje ima vremensko ograničenje od 5 sekundi, pa servis koji ne odgovara ne zadržava odgovor vlasniku. Bez ključa obaveštenje se ne šalje, a potvrda i dalje prolazi.

Potvrda i odbijanje (`ReservationDecisions` u serveru) važe samo za rezervaciju **na čekanju**, i to se proverava u istoj zaključanoj transakciji kao i upis, pa vlasnik ne može da „odbije“ rezervaciju koja je u međuvremenu potvrđena. Razlog odbijanja se čuva u `cancellation_reason`.

**Odbačeno.**
- *Klijent sam šalje e-poštu preko servisa.* Ključ bi morao da bude u aplikaciji, pa bi ga svako mogao izvući iz APK-a ili iz JavaScript-a u pregledaču.
- *Slanje unutar transakcije, pa poništavanje potvrde ako slanje ne uspe.* Spor ili nedostupan servis bi držao zaključan teren i obarao potvrde, a obaveštenje je sporedno u odnosu na samu rezervaciju.

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
| 404 | `not_found` | — |
| 409 | `slot_taken` | `SlotAlreadyTaken` |
| 409 | `invalid_status_transition` | `InvalidReservationStatus` |
| 422 | `invalid_time_range` | `InvalidTimeRange` |
| 422 | `reservation_in_past` | `ReservationInPast` |
| 422 | `outside_working_hours` | `OutsideWorkingHours` |
| 422 | `field_blocked` | `FieldBlocked` |
| 422 | `cancellation_deadline_expired` (`hours`) | `CancellationDeadlineExpired` |
| 422 | `check_in_not_allowed` (`opensHours`, `closesHours`) | `CheckInNotAllowed` |
| 422 | `invalid_duration` | `InvalidReservationDuration` |
| 500 | `internal` | neočekivana greška (detalji samo u logu servera) |

Poruku na srpskom pravi klijent iz koda, istom funkcijom kao kada pravilo proveri lokalno. Nepoznat kod daje opštu poruku („Došlo je do greške. Pokušajte ponovo.“). Konkretan oblik DTO-a definiše `packages/contract` (T40), a prevod `packages/mapping` (T41).
