# Platforma za rezervaciju sportskih terena

Platforma za rezervaciju sportskih terena – Aplikacija koja omogućava vlasnicima sportskih objekata da objavljuju terene za fudbal, košarku, tenis, padel i druge sportove, definišu cene i dostupne termine i upravljaju rezervacijama. Korisnici preko mobilne aplikacije mogu da pretražuju terene prema lokaciji, vrsti sporta, ceni i dostupnosti, rezervišu slobodne termine i prate svoje rezervacije. Vlasnici putem backoffice aplikacije upravljaju svojim terenima, rasporedima i rezervacijama, dok administratori nadgledaju rad platforme.

## Tim

| **Ime i prezime**  | **Broj indeksa** | **Grupa** | **GitHub nalog**   |
| ------------------ | ---------------- | --------- | ------------------ |
| Mihajlo Marinković | 127/24 SI        | 413       | mmarinkovic12724si |
| Ilija Ivković      | 92/24 SI         | 413       | iivkovic9224si     |

## Zahtevi za temu

### 1. Uloge

Sistem ima tri uloge: korisnik, vlasnik sportskog objekta i administrator.

- **Korisnik** – pretražuje sportske terene, pregleda dostupne termine, kreira i otkazuje rezervacije, dodaje terene u omiljene i ocenjuje terene nakon korišćenja.
- **Vlasnik sportskog objekta** – objavljuje i uređuje svoje sportske objekte i terene, određuje cene, radno vreme i dostupne termine, potvrđuje ili odbija zahteve za rezervaciju i prati zauzetost svojih terena.
- **Administrator** – upravlja korisničkim nalozima, odobrava objavljivanje sportskih objekata, nadgleda sadržaj platforme i rešava prijavljene nepravilnosti.

Korisnik vidi samo svoje rezervacije, vlasnik upravlja isključivo svojim objektima i rezervacijama, dok administrator ima pristup podacima potrebnim za upravljanje celokupnom platformom.

### 2. Stanja

Rezervacija sportskog terena prolazi kroz sledeća stanja:

**Na čekanju → Potvrđena → Završena**

Uz dodatno stanje:

- **Otkazana** – korisnik ili vlasnik otkazuje rezervaciju pre početka termina. Kada vlasnik odbije zahtev za rezervaciju, rezervacija takođe prelazi u ovo stanje.

Rezervacija se kreira kada korisnik odabere teren i slobodan termin. Nakon potvrde vlasnika, rezervacija postaje aktivna, a nakon isteka termina prelazi u stanje „Završena“.

### 3. Pravila

- Isti sportski teren ne može imati dve aktivne rezervacije čiji se termini vremenski preklapaju.
- Korisnik ne može rezervisati termin koji je već zauzet ili koji se nalazi van radnog vremena sportskog objekta.
- Korisnik može otkazati rezervaciju najkasnije 2 sata pre početka termina.
- Vlasnik može privremeno blokirati određene termine zbog održavanja terena ili organizovanja događaja.
- Korisnik može oceniti teren samo ukoliko ima završenu rezervaciju za taj teren.
- Samo vlasnik određenog objekta može menjati njegove podatke, cene i raspoloživost.

Server proverava dostupnost termina prilikom kreiranja i potvrđivanja rezervacije. Ukoliko dva korisnika istovremeno pokušaju da rezervišu isti teren u istom terminu, server dozvoljava samo jednu rezervaciju, čime se sprečava duplo rezervisanje.

### 4. Rad bez mreže

Korisnik može bez internet konekcije da pregleda prethodno učitane terene, detalje svojih rezervacija i sačuvane omiljene terene.

Bez mreže može da:
- Doda ili ukloni teren iz omiljenih.
- Oceni teren i napiše recenziju nakon završene rezervacije.

Izmene se čuvaju lokalno na uređaju i automatski sinhronizuju sa serverom kada se internet konekcija ponovo uspostavi.

Server prilikom sinhronizacije proverava da li korisnik ima završenu rezervaciju za ocenjeni teren i da li je već ostavio recenziju za tu rezervaciju. Ukoliko uslovi nisu ispunjeni, recenzija se odbija, a korisnik dobija obaveštenje.

### 5. Posao za osoblje

Vlasnici sportskih objekata koriste backoffice aplikaciju namenjenu radu na većim ekranima.

Backoffice omogućava:

- Pregled svih sportskih objekata i terena koje vlasnik poseduje.
- Dnevni i nedeljni kalendarski prikaz rezervacija za sve terene.
- Pregled slobodnih, zauzetih i blokiranih termina.
- Potvrđivanje, odbijanje i otkazivanje rezervacija.
- Dodavanje novih terena i izmenu njihovih podataka, cena i radnog vremena.
- Pregled statistike zauzetosti terena i broja realizovanih rezervacija.

Administrator kroz backoffice aplikaciju ima pregled svih registrovanih sportskih objekata, vlasnika i korisnika, kao i mogućnost odobravanja novih objekata i upravljanja prijavljenim nepravilnostima.

### 6. Javni sadržaj

Bez prijave na sistem posetiocima su dostupni:

- Katalog sportskih objekata i terena.
- Pretraga i filtriranje prema lokaciji, vrsti sporta i ceni.
- Fotografije, opisi i lokacije sportskih objekata.
- Cenovnici i radno vreme.
- Pregled slobodnih termina za izabrani datum.
- Ocene i komentari prethodnih korisnika.

Javni veb omogućava pretraživačima da indeksiraju stranice sportskih objekata, čime korisnici mogu pronaći terene i putem internet pretrage.

Za kreiranje rezervacije potrebna je prijava na sistem.

## Delovi sistema

| **Deo**            | **Korisnici**                     | **Tehnologija**   | **Platforme**  |
| ------------------ | --------------------------------- | ----------------- | -------------- |
| Mobilna aplikacija | korisnici                         | Flutter           | Android, iOS   |
| Backoffice         | vlasnici objekata, administratori | Flutter           | Veb            |
| Javni veb          | svi posetioci                     | Jaspr             | pregledač      |
| Server             | ostali delovi sistema             | Relic, MySql      | Linux, Windows |
| Domenski paket     | svi delovi sistema                | Dart              | sve            |

## Implementacija KT1

Gore opisana tema je prijavljena tema celog sistema. U KT1 su urađeni zahtevi 1, 2, 3 i 5 za glavni pojam, rezervaciju terena. Zahtev 4 (rad bez mreže) ulazi u KT3, a zahtev 6 (javni sadržaj) u KT4.

### Kako se pokreće

```bash
flutter pub get          # u korenu repozitorijuma (pub workspace)
cd apps/mobile && flutter run          # Android emulator ili telefon
cd apps/backoffice && flutter run -d windows   # desktop
cd apps/backoffice && flutter run -d chrome    # veb
```

Testovi: `dart test` u `packages/domain` i `packages/blocs`, `flutter test` u `apps/mobile` i `apps/backoffice`.

### Struktura

| Folder | Sadržaj |
| ------ | ------- |
| `packages/domain` | Čist Dart paket: model, stanja, pravila i `ReservationRepository` (port). Koriste ga oba klijenta. |
| `packages/blocs` | Čist Dart paket: `ReservationBloc` (događaji i stanja, `Equatable`). |
| `apps/mobile` | Flutter aplikacija za korisnike (Android), `go_router`, tema, ikonica. |
| `apps/backoffice` | Flutter aplikacija za osoblje (desktop i veb). |

Svaki klijent ima svoju lažnu implementaciju repozitorijuma u memoriji (`MobileFakeRepository`, `BackofficeFakeRepository`) sa kašnjenjem. Podaci nisu sinhronizovani između klijenata.

### Stanja u KT1

Rezervacija ima četiri stanja (`ReservationStatus`): **na čekanju, potvrđena, završena i otkazana**. Dozvoljeni prelazi (`canTransitionReservationStatus`):

- na čekanju → potvrđena ili otkazana,
- potvrđena → završena ili otkazana,
- završena i otkazana su konačna.

Odbijanje zahteva od strane vlasnika vodi u stanje „otkazana“ (u backoffice-u je akcija „Odbij“ za rezervaciju na čekanju, a „Otkaži“ za potvrđenu).

### Zahtevi KT1

**1. Uloge.** Mobilna aplikacija radi kao jedan korisnik (pregled terena, rezervisanje, otkazivanje svojih rezervacija), a backoffice radi kao vlasnik objekta (pregled, potvrda, odbijanje i otkazivanje rezervacija svojih terena). Prijava stiže u KT2.

**2. Stanja.** Rezervacija prolazi kroz stanja iz sekcije iznad. Korisnik kreira i otkazuje rezervaciju, a vlasnik potvrđuje, odbija i otkazuje. Dozvoljene prelaze određuje jedna funkcija u domenskom paketu.

**3. Pravila.** Pravila su u `packages/domain/lib/src/rules` i vraćaju grešku kao `sealed` tip (`ReservationValidationError`), a poruke na srpskom bira aplikacija. Pravila: preklapanje termina istog terena, radno vreme terena, blokirani periodi, otkazivanje najkasnije 2 sata pre početka, provera prelaza stanja. Forma za rezervaciju u mobilnoj aplikaciji proverava unos ovim pravilima, a ista pravila koristi i backoffice.

**5. Posao za osoblje.** Backoffice prikazuje rezervacije u tabeli, sa detaljima u bočnom panelu, i omogućava potvrđivanje, odbijanje i otkazivanje. Radi i tastaturom: ↑ ↓ (kretanje), Home / End, Enter (akcije), P (potvrdi), O (odbij / otkaži), R (osveži), Esc (nazad). Ispod širine od 900 px tabela prelazi u listu, a izabrana rezervacija se čuva.

### Mobilna aplikacija

- 15 lažnih rezervacija, sva četiri stanja zastupljena.
- Ekrani: početna, katalog terena, detalj terena, forma za rezervaciju, moje rezervacije.
- Otkazivanje traži potvrdu u dijalogu.
- Ekran rezervacija prikazuje učitavanje, grešku sa dugmetom „Pokušaj ponovo“, prazan prikaz i podatke. Meni simulacije izaziva grešku ili prazan odgovor sledećeg zahteva.

### Domenski paket

- Model: `Reservation`, `SportsField`, `FieldSchedule`, `AppUser`, `Review` sa `final` poljima i posebnim tipovima identifikatora.
- Pravila nad listama (preklapanje, blokirani periodi, radno vreme) računaju se u paketu; konačnu odluku o njima donosi server u KT2.
- U paketu nema `package:flutter`, `dart:io`, `dart:ffi` ni `dart:js_interop`.

### Upravljanje stanjem

- `ReservationBloc` vodi učitavanje i promenu statusa rezervacije; stanja su `Equatable`.
- Podaci stižu kroz `ReservationRepository` (`abstract interface class`), pa se implementacija menja bez izmene ekrana.
- Ekrani samo šalju događaje i crtaju stanje.
