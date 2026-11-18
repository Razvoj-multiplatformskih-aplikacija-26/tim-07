# mapping

Prevod između domena (`packages/domain`) i HTTP ugovora (`packages/contract`), na jednom mestu.
Isti kod koriste server (domen → DTO za odgovor, DTO → domen za zahtev) i klijenti (obrnuto), pa se prevod ne duplira.

Pisan je kao extension metode, `toDto()` i `toDomain()`, kao u primeru Rafstoran (`api_mapping`).

| Fajl | Šta prevodi |
| ---- | ----------- |
| `src/codes_mapping.dart` | enum ↔ kod na mreži (`reservationStatusToCode`, `sportFromCode`, ...), `UnknownCodeException` |
| `src/reservation_mapping.dart` | `Reservation` ↔ `ReservationDto`, zahtev za kreiranje |
| `src/field_mapping.dart` | teren, sportovi, radno vreme, blokirani periodi |
| `src/user_mapping.dart` | `AppUser` ↔ `UserDto` |
| `src/stats_mapping.dart` | `OccupancyReport` ↔ `OccupancyReportDto` |
| `src/error_mapping.dart` | greške pravila ↔ `ErrorDto` (kod + podaci), `ApiFailure` sa HTTP statusom, `failureOf(izuzetak)` |

## Pravila

- Kod na mreži se ne uzima iz `enum.name`: preimenovanje u domenu ne sme tiho da promeni ugovor.
- **Nepoznat kod** (server noviji od aplikacije) ne obara aplikaciju: `toDomain()` baca `UnknownCodeException`,
  `toDomainOrNull()` vraća `null`, a `toDomainKnown()` nad listom preskače taj zapis. Nepoznat kod greške daje `null`
  iz `toValidationError()`, pa klijent prikazuje opštu poruku.
- Greška nosi samo kod i podatke pravila (`hours`, `opensHours`, `closesHours`); rokovi dolaze iz domena
  (`Reservation.checkInOpensHoursBefore`, `checkInClosesHoursBefore`), pa poruka klijenta ne može da se razilazi sa pravilom.
- Statistika čuva tačne granice perioda iz odgovora (`StatsPeriod.exact`), ne računa ih po zoni uređaja.
- `UserDto` ne nosi datum rođenja; šta nije stiglo (telefon, datum rođenja, registracija) popunjava se neutralnom vrednošću
  i klijent ne sme da je prikazuje.
