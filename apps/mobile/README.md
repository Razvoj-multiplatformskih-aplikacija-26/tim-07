# mobile

Mobilna aplikacija za korisnike (Flutter, Android i iOS). Pregled terena, rezervisanje i moje rezervacije.

```sh
flutter pub get          # u korenu repozitorijuma (pub workspace)
cd apps/mobile && flutter run
flutter test
```

## Server

Aplikacija radi nad serverom (`apps/server`), ne nad podacima u memoriji. Podaci stižu preko `MobileServer` (`lib/data/mobile_server.dart`),
jedinog mesta koje zna za HTTP: pravi `HttpReservationRepository`, `HttpFieldRepository`, `HttpScheduleRepository`,
`HttpAvailabilityRepository` i `HttpSessionRepository` iz `packages/api_client`. `MyApp`, ekrani i Bloc-ovi primaju portove iz domena,
pa isti kod radi i nad lažnim repozitorijumima (testovi `*_screen_test.dart`) i nad serverom (`server_flow_test.dart`).

- **Adresa servera** se zadaje pri pokretanju, bez izmene koda: `flutter run --dart-define=SERVER_URL=http://192.168.0.5:8080`.
  Bez nje se uzima ona koja radi na tom uređaju (`lib/server_address.dart`): Android emulator `http://10.0.2.2:8080`, ostalo `http://localhost:8080`.
  Pravi telefon sa USB kablom: `adb reverse tcp:8080 tcp:8080`, pa `--dart-define=SERVER_URL=http://localhost:8080`.
- **Android** traži dozvolu `INTERNET` (u glavnom manifestu) i dozvoljava HTTP bez TLS-a samo za `10.0.2.2`, `localhost` i `127.0.0.1`
  (`android/app/src/main/res/xml/network_security_config.xml`). Za svaki drugi server treba HTTPS.
- **Server nedostupan:** zahtev ističe posle 10 sekundi, pa ekran pokaže poruku „Server trenutno nije dostupan.“ i „Pokušaj ponovo“, ne ostaje
  u učitavanju bez kraja. Isto važi za slanje rezervacije: unos ostaje, pa se ponovno slanje može pokušati.
- **Odbijen poziv** (npr. termin koji je neko drugi zauzeo): ekran prikazuje razlog iz koda greške (ista poruka kao kad pravilo proveri klijent),
  a forma ponovo čita radno vreme, blokade i rezervacije korisnika.
- **Prijava:** token čuva `session_storage` (bezbedno skladište platforme), a nalog dolazi sa servera. Demo nalozi su u glavnom README-u.

## Prijava

Katalog terena (`/`, `/fields`, `/fields/:id`) je javan. Rezervisanje i moje rezervacije traže prijavu:
bez nje router vodi na `/login?from=<adresa>`, a posle prijave nazad na tu adresu.

- Prijavu vodi zajednički `AuthBloc` (`packages/blocs`) nad `AuthRepository`. Aplikacija koristi `HttpSessionRepository`;
  `FakeAuthRepository` sa demo nalozima (`MobileDemoData.accounts`) ostaje za testove ekrana.
- Prijavljen korisnik se čita iz `AuthBloc`-a (`context.watchUser` / `context.readUser`), nigde iz demo podataka.
- Mobilna aplikacija prima samo korisnike (`canSignIn` iz domena): vlasnik se odbija uz poruku, a prijava se ne pamti.
- Istek prijave: na zaštićenom ekranu aplikacija vraća na prijavu uz poruku „Prijava je istekla. Prijavite se ponovo.“,
  a na javnom ekranu ostaje gde jeste i obaveštava u traci. Posle nove prijave se vraća na isti ekran.
- Odjava je u meniju naloga (ikona u traci aplikacije); briše prijavu i rezervacije učitane za tog korisnika.

## Katalog terena

Tereni dolaze iz `SportsFieldRepository` (u aplikaciji `HttpFieldRepository`, u testovima lažni repozitorijum u memoriji), ne iz demo podataka u ekranima.

- `FieldsBloc` (`packages/blocs`) drži katalog: učitavanje, pretragu, sport i redosled. Ima četiri stanja ekrana: učitavanje,
  greška sa „Pokušaj ponovo“, prazan katalog i tereni. Pretraga, sport i redosled se primenjuju nad učitanom listom, bez novog zahteva,
  a ostaju i posle osvežavanja i povratka na ekran. Filteri koji ništa ne pronađu nisu prazan katalog.
- `FieldDetailsBloc` učitava jedan teren po adresi `/fields/:fieldId` (`FieldLoader`): učitavanje, greška, „Teren nije pronađen.“ i teren.
  Teren koji nije javan (neodobren, neaktivan) se ne vidi ni preko adrese.
- Brzi filter sportova (čipovi) se pravi od sportova koji postoje na terenima u katalogu (`FieldsState.sports`), ne iz fiksne liste:
  novi sport na nekom terenu dobija čip posle osvežavanja, bez izmene koda, a sport bez javnog terena nema čip. Izabrani sport koji više
  ne postoji se skida pri osvežavanju. Ikonica terena se bira po `SportType` (`sportIcon`), ne po tekstu.
- Slobodni termini na detalju terena dolaze iz `AvailabilityBloc` (`AvailabilityRepository`), ne iz liste sati u ekranu: pravilo
  `calculateAvailability` iz domena računa termine iz radnog vremena terena, rezervacija svih korisnika i blokada, a isto pravilo će
  koristiti server. Stanja termina: slobodan, zauzet, blokiran i prošao; dan na koji teren ne radi je poseban prikaz. Posle povratka
  sa forme za rezervaciju termini se osvežavaju.
- Forma za rezervaciju je `ReservationFormBloc`: provera termina uživo istim pravilima iz domena (`validateReservationSlot`) nad radnim
  vremenom, blokadama i korisnikovim rezervacijama, cena, slanje i ishod. Stanja: učitavanje, unos, slanje, uspeh, odbijeno sa razlogom
  i neuspelo (nema servera). Kada server odbije termin (npr. zauzet je u međuvremenu), korisnik vidi istu poruku kao da je pravilo
  proverio klijent, unos ostaje, a podaci za proveru se ponovo učitavaju. Ekran samo šalje događaje i crta stanje.
- Nazivi terena u rezervacijama dolaze iz kataloga (`context.fieldName`), a dok se katalog ne učita vidi se „Teren #id“.
- Meni simulacije na katalogu izaziva grešku ili prazan odgovor sledećeg zahteva.

## Demo nalozi

Lozinka svih demo naloga je `lozinka123`.

| E-mail | Uloga | Napomena |
| ------ | ----- | -------- |
| `marko.markovic@example.com` | korisnik | ima rezervacije u svim stanjima |
| `jelena.nikolic@example.com` | korisnik | druge rezervacije, ne vidi Markove |
| `petar.vlasnik@example.com` | vlasnik | mobilna aplikacija ga odbija (za backoffice je) |

## Adrese

| Adresa | Ekran | Prijava |
| ------ | ----- | ------- |
| `/` | početna | ne |
| `/fields` | katalog terena | ne |
| `/fields/:fieldId` | detalj terena | ne |
| `/fields/:fieldId/reserve?date=&start=&end=` | forma za rezervaciju | da |
| `/reservations` | moje rezervacije | da |
| `/reservations/:reservationId` | detalj rezervacije | da |
| `/login?from=` | prijava | |
