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
