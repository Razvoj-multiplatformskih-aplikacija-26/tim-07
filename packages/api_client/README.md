# api_client

Repozitorijumi preko HTTP-a: isti kod za mobilnu aplikaciju i backoffice, na VM-u (telefon, desktop) i u pregledaču.
Koristi samo `package:http`, bez `dart:io` (proverava `test/purity_test.dart`), a testovi rade i na VM-u i u Chrome-u
(`dart_test.yaml`: `platforms: [vm, chrome]`).

| Klasa | Port iz `domain` | Šta radi |
| ----- | ---------------- | -------- |
| `ApiClient` | | HTTP, token u `Authorization`, vremensko ograničenje, greške |
| `HttpReservationRepository` | `ReservationRepository` | rezervacije, strana liste, odbijanje sa razlogom |
| `HttpFieldRepository` | `SportsFieldRepository` | tereni, katalog sa filterima, `getAvailableSports()` |
| `HttpScheduleRepository` | `FieldScheduleRepository` | radno vreme i blokirani periodi |
| `HttpStatisticsRepository` | `StatisticsRepository` | zauzetost (računa server) |
| `HttpSessionRepository` | | prijava, vraćanje prijave posle restarta, odjava |
| `SessionStore`, `MemorySessionStore` | | port za čuvanje tokena (implementacije platformi: T49) |

## Greške

Sve što pođe naopako stiže kao jedan od dva izuzetka iz paketa `messages`, pa Bloc i ekran ne znaju ništa o HTTP-u:

- `ServerUnreachableException`: nema mreže, server ne radi ili ne odgovara u roku (podrazumevano 10 s). Ekran to kaže i ne ostaje u učitavanju.
- `ServerRejectedException(ErrorDto)`: server je odgovorio greškom (kod i podaci pravila). Telo koje nije greška servera (HTML sa proxy-ja) postaje `internal`, bez tehničkog teksta.

`token_expired` i `invalid_token` brišu token iz `SessionStore` i javljaju se na `expirations`; pogrešna lozinka (`invalid_credentials`) nije istek.
`HttpSessionRepository.restore()` ne briše prijavu kada servera nema: korisnik ne sme da bude odjavljen samo zato što je mreža pala.

## Pravila

- Identitet je u tokenu: zahtevi nemaju `userId`, vlasnika terena ni administratora (odluka 11).
- Liste se uzimaju po stranama (`limit` do 100, `offset`), a port koji traži celu listu dobija sve strane. Za tabelu: `getReservationsPage`, `getFieldsPage`.
- Zapis sa kodom koji ova verzija ne poznaje (nov sport, nova uloga) se preskače u listi, a u detalju daje grešku servera: aplikacija ne pada.
- Tuđa ili nepostojeća rezervacija stiže kao 404, pa `getReservationById` vraća `null`.
- Adresa servera se zadaje spolja (`baseUri`), npr. `http://10.0.2.2:8080` za Android emulator.

## Šta server (T44) mora da podrži

Adrese su u `contract` (`ApiPaths`). Dva izbora koja ovaj paket pravi:

- `POST /reservations/:id/cancel` mora da prihvati i vlasnika nad rezervacijom na čekanju (odbijanje bez razloga),
  jer `updateReservationStatus(cancelled)` ne zna da li je zahtev čekao. `/reject` je za odbijanje sa razlogom.
- Liste (`/reservations`, `/fields`, `/fields/awaiting-approval`, `/fields/:id/blocked-periods`) vraćaju `{items, total, limit, offset}`.
