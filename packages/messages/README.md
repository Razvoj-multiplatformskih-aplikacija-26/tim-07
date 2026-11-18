# messages

Poruke za korisnika na srpskom, iz kodova grešaka. Server šalje samo kod i podatke pravila (`ErrorDto`),
a poruku pravi klijent, ovim paketom. Čist Dart, koriste ga mobilna aplikacija, backoffice i `blocs`.

| Funkcija | Šta radi |
| -------- | -------- |
| `errorMessage(ErrorDto)` | jedino mesto gde se pravi tekst; nepoznat kod daje `genericErrorMessage` |
| `validationMessage(ReservationValidationError)` | poruka za pravilo koje je klijent sam proverio; prolazi kroz `errorMessage` |
| `describeError(Object)` | poruka za bilo koju grešku koju Bloc uhvati; nikad tehnički tekst |
| `isSessionExpired(Object)` | da li je prijava istekla (`token_expired`) |
| `ServerRejectedException`, `ServerUnreachableException` | izuzeci koje baca HTTP repozitorijum (T43), a hvata Bloc |

Pravila:

- Ista poruka za isto pravilo, bez obzira da li ga je proverio klijent ili server (`test/messages_test.dart`).
- Granica u poruci (npr. „5 sati“) dolazi iz `details` greške, ne iz aplikacije. Ako `details` fali, poruka je bez broja.
- Kod koji ova verzija ne poznaje (aplikacija starija od servera) daje opštu poruku; aplikacija ne pada i kod se ne prikazuje.
- `describeError` ne prepisuje `toString()` izuzetka: `Bad state`, `FormatException`, SQL i slično se nikad ne vide.
  Jedini izuzetak je `StateError` iz demo repozitorijuma, čija je poruka namerno napisana za korisnika.
