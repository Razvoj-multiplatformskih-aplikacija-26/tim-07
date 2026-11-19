# mobile

Mobilna aplikacija za korisnike (Flutter, Android i iOS). Pregled terena, rezervisanje i moje rezervacije.

```sh
flutter pub get          # u korenu repozitorijuma (pub workspace)
cd apps/mobile && flutter run
flutter test
```

## Prijava

Katalog terena (`/`, `/fields`, `/fields/:id`) je javan. Rezervisanje i moje rezervacije traže prijavu:
bez nje router vodi na `/login?from=<adresa>`, a posle prijave nazad na tu adresu.

- Prijavu vodi zajednički `AuthBloc` (`packages/blocs`) nad `AuthRepository`. Dok aplikacija nema server (T52), iza njega je
  `FakeAuthRepository` sa demo nalozima (`MobileDemoData.accounts`); sa serverom ga menja `HttpSessionRepository`.
- Prijavljen korisnik se čita iz `AuthBloc`-a (`context.watchUser` / `context.readUser`), nigde iz demo podataka.
- Mobilna aplikacija prima samo korisnike (`canSignIn` iz domena): vlasnik se odbija uz poruku, a prijava se ne pamti.
- Istek prijave: na zaštićenom ekranu aplikacija vraća na prijavu uz poruku „Prijava je istekla. Prijavite se ponovo.“,
  a na javnom ekranu ostaje gde jeste i obaveštava u traci. Posle nove prijave se vraća na isti ekran.
- Odjava je u meniju naloga (ikona u traci aplikacije); briše prijavu i rezervacije učitane za tog korisnika.

## Katalog terena

Tereni dolaze iz `SportsFieldRepository` (iza njega je lažni repozitorijum u memoriji, dok nema servera), ne iz demo podataka u ekranima.

- `FieldsBloc` (`packages/blocs`) drži katalog: učitavanje, pretragu, sport i redosled. Ima četiri stanja ekrana: učitavanje,
  greška sa „Pokušaj ponovo“, prazan katalog i tereni. Pretraga, sport i redosled se primenjuju nad učitanom listom, bez novog zahteva,
  a ostaju i posle osvežavanja i povratka na ekran. Filteri koji ništa ne pronađu nisu prazan katalog.
- `FieldDetailsBloc` učitava jedan teren po adresi `/fields/:fieldId` (`FieldLoader`): učitavanje, greška, „Teren nije pronađen.“ i teren.
  Teren koji nije javan (neodobren, neaktivan) se ne vidi ni preko adrese.
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
