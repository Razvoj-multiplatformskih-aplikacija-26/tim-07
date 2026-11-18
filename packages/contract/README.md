# contract

HTTP ugovor između klijenata (mobilna aplikacija, backoffice) i servera: DTO zahteva i odgovora,
kodovi grešaka, adrese i oblik JSON-a. Čist Dart bez zavisnosti: ne uvozi `domain`, Flutter ni `dart:io`
(proverava `test/purity_test.dart`). Prevod DTO ↔ domen je u paketu `mapping` (T41).

Odluke o obliku na mreži su u `docs/kt2-decisions.md` (odluke 5, 6, 8, 9, 13, 14).

| Fajl | Sadržaj |
| ---- | ------- |
| `src/paths.dart` | `ApiPaths`, `ApiQuery`, `ApiPaging`, `ApiHeaders` |
| `src/codes.dart` | stabilni tekstualni kodovi: stanje, sport, uloga, odobrenost, termin |
| `src/error_dto.dart` | `ErrorDto` (`{"error": {"code", "details"}}`) i `ErrorCodes` |
| `src/page_dto.dart` | `PageDto<T>` (`items`, `total`, `limit`, `offset`) |
| `src/reservation_dto.dart`, `field_dto.dart`, `schedule_dto.dart`, `stats_dto.dart`, `user_dto.dart` | zahtevi i odgovori |

Pravila ugovora:

- Novac je ceo broj dinara, trenutak je ISO-8601 u UTC sa `Z` (trenutak bez zone se odbija), radno vreme je `HH:mm`.
- Stanja, sportovi i uloge su `String` kodovi. Nepoznat kod prolazi neoštećen kroz DTO, pa stara aplikacija ne pada.
- Nepoznata polja u JSON-u se ignorišu, obavezno polje koje fali baca `FormatException`.
- Zahtevi ne nose `userId` ni vlasnika: server ih uzima iz tokena.
- Greška nosi kod i podatke pravila, poruku pravi klijent.
