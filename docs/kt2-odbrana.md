# Odbrana KT2: šta pokazujemo i kako

Ovaj spisak prati redove „Na odbrani“. Svaka stavka kaže **šta pokazati**, **kako**, **gde je u kodu** i **šta treba da se vidi**. Komande su izvršene nad pravim sistemom (Docker, PostgreSQL 17, server iz `apps/server`) i rezultati su zapisani onakvi kakvi su bili.

## Priprema

```sh
cp .env.example .env            # jednom, bez izmena
docker compose up -d --build    # baza, migracije, server na http://localhost:8080
```

- Demo nalozi i lozinka (`DEMO_PASSWORD` iz `.env`) su u glavnom README-u. Početni podaci: 6 naloga, 4 terena, 11 rezervacija u sva četiri stanja.
- Mobilna aplikacija: `cd apps/mobile && flutter run` (emulator vidi server na `10.0.2.2:8080`). Backoffice: `cd apps/backoffice && flutter run -d windows` ili `-d chrome --web-port 8081`.
- Za `curl` primere ispod: `B=http://localhost:8080`, a `TOKEN` je `token` iz odgovora na `POST /auth/login`.

```sh
B=http://localhost:8080; DP=<DEMO_PASSWORD>
tok() { curl -s -X POST $B/auth/login -H 'Content-Type: application/json' \
  -d "{\"email\":\"$1\",\"password\":\"$DP\"}" | python -c "import json,sys; print(json.load(sys.stdin)['token'])"; }
ANA=$(tok korisnik1@terenzo.rs); MARKO=$(tok korisnik2@terenzo.rs); OWN=$(tok vlasnik1@terenzo.rs)
```

## 1. Izmena pravila uživo (domen → server → oba klijenta)

**Pravilo:** korisnik otkazuje najkasnije 5 sati pre početka. **Izmena:** 3 sata.

1. `packages/domain/lib/src/models/reservation.dart`: `checkInClosesHoursBefore = 5` → `3`. Pravilo `validateCancellation` (`packages/domain/lib/src/rules/reservation_validation.dart`) čita tu konstantu; nema druge kopije broja.
2. Broj u poruci ne piše klijent: `packages/mapping/lib/src/error_mapping.dart` ga stavlja u `details.hours`, a `packages/messages/lib/src/error_messages.dart` (`_cancellationMessage`) pravi tekst „manje od 3 sata pre početka“.
3. `dart test` u `packages/domain`, `packages/mapping`, `packages/messages`, `packages/api_client`: pada oko 12 testova koji **pišu staro pravilo** (npr. „check-in tačno 5 sati pre početka nije validan“, „rok otkazivanja nosi broj sati iz domena“). To je poenta: testovi su ugovor pravila, pa se menjaju zajedno sa njim. `packages/blocs`, `apps/mobile` i `apps/backoffice` ostaju zeleni jer ne znaju broj.
4. Server: `docker compose up -d --build server` (pravilo se kompajlira u sliku). Provera pre i posle izmene je ista rezervacija, koja počinje za 4 sata i ima check-in (bez check-in-a je sistem sam otkaže pre roka):

   ```sh
   docker compose exec -T db psql -U terenzo -d terenzo -tAc "INSERT INTO reservations
     (field_id,user_id,start_time,end_time,total_price,status,checked_in_at)
     SELECT 2,u.id,now()+interval '4 hours',now()+interval '5 hours',1500,'confirmed',now()-interval '2 hours'
     FROM users u WHERE u.email='korisnik1@terenzo.rs' RETURNING id"
   curl -X POST $B/reservations/<id>/cancel -H "Authorization: Bearer $ANA"
   ```

   Sa 5 sati (izvršeno): `422 cancellation_deadline_expired`, `"details":{"hours":5}`. Sa 3 sata: `200`, rezervacija je otkazana, a za rezervaciju koja počinje za 2 sata i dalje `422` sa `"hours":3` (ova polovina nije izvršena uživo, samo kroz testove domena).
5. Klijenti: ponovo pokrenuti (`r` / `R` ne dovodi novi domenski kod, treba potpun restart). Obe aplikacije prikazuju novu poruku bez ijedne izmene u aplikaciji.

Ako pitaju zašto jedna izmena: pravilo je u domenu, a server i oba klijenta ga uvoze (odluka 2).

## 2. Poziv mimo aplikacije (curl) i tuđ zapis

| Šta | Komanda | Odgovor |
| --- | ------- | ------- |
| Bez prijave | `curl $B/reservations` | `401 unauthenticated` |
| Lažan token | `curl $B/reservations -H "Authorization: Bearer abc.def.ghi"` | `401 invalid_token` |
| Korisnik potvrđuje | `curl -X POST $B/reservations/<id>/confirm -H "Authorization: Bearer $ANA"` | `403 forbidden` |
| Tuđa rezervacija | `curl $B/reservations/<id od Ane> -H "Authorization: Bearer $MARKO"` | `404 not_found` (ne `403`, da se ne otkrije da postoji; odluka 4) |
| Vlasnik traži naloge | `curl $B/users -H "Authorization: Bearer $OWN"` | `403 forbidden` |
| Pokvaren telo | `curl -X POST $B/reservations -H "Authorization: Bearer $ANA" -H 'Content-Type: application/json' -d '{"fieldId":"x"}'` | `400 bad_request`, `"reason":"Expected \"fieldId\" to be an integer"` |

Server nikad ne veruje klijentu: korisnik dolazi iz tokena, a `userId` u telu se ignoriše (test „server uzima korisnika iz tokena“).

## 3. Zakasneli klijent

Dva korisnika traže isti termin:

```sh
curl -X POST $B/reservations -H "Authorization: Bearer $ANA" -H 'Content-Type: application/json' \
  -d '{"fieldId":1,"startTime":"2026-11-28T16:00:00.000Z","endTime":"2026-11-28T17:00:00.000Z"}'      # 201
curl -X POST $B/reservations -H "Authorization: Bearer $MARKO" -H 'Content-Type: application/json' \
  -d '{"fieldId":1,"startTime":"2026-11-28T16:00:00.000Z","endTime":"2026-11-28T17:00:00.000Z"}'     # 409 slot_taken
```

Prvi dobija `201`, drugi `409 slot_taken`. Konačnu reč ima baza (ograničenje isključenja na preklapanje, odluka 2), a ne klijent. U aplikaciji: forma ostaje sa unosom, prikazuje „Termin se preklapa sa postojećom rezervacijom.“ i ponovo čita podatke (`ReservationFormBloc`).

## 4. Put jedne greške do poruke u oba klijenta

`slot_taken`: baza odbija upis (`23P01`, `apps/server/lib/src/terenzo_store.dart`) → server pravi `ErrorDto(code)` (`apps/server/lib/src/http.dart`) → `409` → `ApiClient` baca `ServerRejectedException` (`packages/api_client/lib/src/api_client.dart`) → `packages/mapping` ga pretvara u domensku grešku → `describeError` / `errorMessage` u `packages/messages` daje srpski tekst → Bloc (`ReservationFormBloc`, `ReservationBloc`) ga stavlja u stanje → ekran ga samo crta. Isti tekst dobija i lokalna provera pravila (`validationMessage`), pa korisnik ne vidi razliku.

## 5. Stara verzija aplikacije

Server pošalje kod koji aplikacija ne poznaje: `ErrorDto.isKnown` je `false`, a `errorMessage` daje opštu poruku „Došlo je do greške. Pokušajte ponovo.“ umesto pada. Isto za nepoznato stanje rezervacije, sport ili ulogu: zapis se preskače (`toDomainKnown`), lista ostaje. Testovi: `nepoznat kod greške (stara aplikacija) daje opštu poruku` (api_client), `nepoznato stanje prolazi neoštećeno` (contract).

## 6. Podizanje iz čistog klona

`git clone`, `cp .env.example .env`, `docker compose up -d --build` (prvi put oko 15 minuta zbog povlačenja Dart slike, kasnije par minuta). Server sam čeka bazu i migracije (`depends_on: migrate`), a seed upisuje samo nad praznom bazom. Provera: `curl $B/health` → `ok`.

## 7. Promena iz mobilne vidljiva u backoffice-u

Mobilna: korisnik rezerviše termin. Backoffice (vlasnik terena): lista rezervacija se sama osvežava na 30 sekundi dok je stranica otvorena (`ReservationsPage.refreshEvery`, odluka 7), a odmah sa `R` ili „Osveži“. Nova rezervacija je „na čekanju“ za teren sa ručnom potvrdom. Pošto je lista na serveru, pojavljuje se i uz filtere i strane (odluka 19), a vlasnik vidi ime i telefon korisnika (odluka 21).

## 8. Zaustavljen server

`docker compose stop server`. Mobilna i backoffice: „Server trenutno nije dostupan.“ uz „Pokušaj ponovo“, bez beskonačnog učitavanja (zahtev ističe posle 10 s). Ponovo: `docker compose start server`; backoffice se oporavi sam u roku od 30 s, mobilna na „Pokušaj ponovo“.

## 9. Bloc-ovi koje dele oba klijenta

Svi su u `packages/blocs` i rade samo preko portova iz domena: `AuthBloc` (prijava u obe aplikacije), `ReservationBloc` (akcije nad rezervacijom), `FieldsBloc` i `FieldDetailsBloc` (katalog), `AvailabilityBloc`, `ReservationFormBloc`. Samo backoffice: `ReservationListBloc`, `CalendarBloc`, `BlockedPeriodsBloc`, `FieldManagementBloc`, `FieldReviewBloc`, `StatisticsBloc`, `UsersBloc`. Lokalno u backoffice-u ostaju samo `ReservationSelectionBloc` i `DirectoryCubit` (odluka 18). U lažnim repozitorijumima isti Bloc-ovi rade u testovima.

## 10. Prijava, restart i odjava na svakoj platformi

Token čuva `packages/session_storage`: bezbedno skladište platforme (Keystore na Androidu, Credential Manager na Windowsu, Keychain na macOS-u/iOS-u) ili `localStorage` u pregledaču. Lozinka se ne čuva. Pri pokretanju `AuthStarted` traži `GET /auth/me`: važeći token vraća na isti ekran, nevažeći se briše. Odjava briše token i rezervacije učitane za tog korisnika. Backoffice odbija prijavu korisnika mobilne aplikacije, a mobilna prijavu osoblja (`canSignIn`).

## 11. Istekla prijava

`SESSION_TTL_MINUTES=1 docker compose up -d server`, prijava, pa čekati minut. Sledeći zahtev dobija `401 token_expired`: `ApiClient` briše token i javlja istek, mobilna na zaštićenom ekranu vraća na prijavu uz „Prijava je istekla. Prijavite se ponovo.“ i posle prijave na isti ekran. Deaktiviran nalog (odluka 20) ima isti ishod: `403 account_deactivated`, token se briše.

## 12. „Šta ako stigne treći klijent (javni veb)?“

Server i domen se ne menjaju. Veb klijent koristi iste pakete (`api_client` radi u pregledaču jer koristi samo `package:http`), `session_storage` ima varijantu za pregledač, a token ide u `Authorization` zaglavlju, ne u kolačiću, pa nema CSRF. Treba samo: dodati njegovo poreklo u `CORS_ORIGINS` u `.env` (server dozvoljava samo navedena), a bez prijave vidi samo javni katalog (`/fields`, `/sports`, odluka 8). Novi klijent dobija ista prava po ulozi jer ih proverava server, ne klijent.

## Odbačene mogućnosti po odlukama

Za svaku odluku iz `docs/kt2-decisions.md` znamo šta je odbačeno i zašto; ovo je skraćeni pregled, a razlozi su u samoj odluci.

| # | Odluka | Odbačeno |
| - | ------ | -------- |
| 1 | Vrsta pravila: preklapanje u vremenu | Fiksni slotovi od po sat vremena sa jedinstvenim ključem (teren, početak) u bazi |
| 2 | Ko konačno čuva pravilo: server uz zaštitu u bazi | Samo provera u klijentu; MySQL i zaključavanje reda terena i korisnika (`SELECT … FOR UPDATE`); Okidač (trigger) u bazi koji odbija preklapanje; Nivo izolacije `SERIALIZABLE` za celu bazu |
| 3 | Šta vidi zakasneli klijent | Poslednji upis pobeđuje (last write wins); Lista čekanja za zauzet termin |
| 4 | Šta koja uloga vidi | Server vraća sve, a klijent filtrira |
| 5 | Format novca, vremena i stanja na mreži | Novac kao `double`; Vreme kao broj milisekundi od 1970; Stanje kao indeks enuma (`0, 1, 2…`) |
| 6 | Kako klijent traži deo velike liste | Kursor (`?after=<id>`) |
| 7 | Kako klijent saznaje za tuđu promenu | Server šalje promene (WebSocket ili Server-Sent Events) |
| 8 | Šta je javno bez prijave | Sve iza prijave |
| 9 | Ko sme da menja tuđi zapis i u kojim stanjima | Provere uloga u svakom ekranu i u svakoj ruti servera posebno |
| 10 | Šta pregledač ne dozvoljava (CORS) | `Access-Control-Allow-Origin: *`; posrednik (proxy) koji servira backoffice i API sa istog porekla |
| 11 | Prijava i token | `sessionStorage` (nestaje sa zatvaranjem taba); kolačić (CSRF, `Allow-Credentials`) |
| 12 | Spoljni servis iza porta | Klijent sam šalje e-poštu preko servisa; Slanje unutar transakcije, pa poništavanje potvrde ako slanje ne uspe |
| 13 | Greške na mreži | Server šalje gotovu poruku na srpskom; HTTP status kao jedini nosilac greške |
| 14 | Statistika zauzetosti | Računanje u klijentu; Ceo proračun u jednom SQL upitu |
| 15 | Blokiranje termina | Blokada preko potvrđene rezervacije koja otkazuje rezervaciju; Provera samo u klijentu |
| 16 | Baza, migracije i početni podaci | MySQL sa pokretačem migracija u samom serveru; Početni podaci kao SQL migracija |
| 17 | Kalendar rezervacija | Mreža sa satnicom (visina reda prema trajanju); Svi tereni u nedeljnom prikazu |
| 18 | Gde je Bloc, a gde lokalno stanje (backoffice) | Bloc za svaku stranicu i svaki dijalog |
| 19 | Tabela rezervacija: filteri, pretraga, sortiranje i strane | Filtriranje u klijentu nad celom listom; Kursor umesto `offset` |
| 20 | Nalozi: pregled i deaktivacija (administrator) | Brisanje naloga; Deaktivacija samo zabranjuje novu prijavu |
| 21 | Ko je rezervisao: podaci uz rezervaciju za osoblje terena | `GET /users/:id` za vlasnika |
