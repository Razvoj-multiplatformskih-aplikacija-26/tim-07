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

**Na čekanju → Potvrđena → U toku → Završena**

Uz dodatna stanja:

- **Odbijena** – vlasnik odbija zahtev za rezervaciju.
- **Otkazana** – korisnik ili vlasnik otkazuje rezervaciju pre početka termina.

Rezervacija se kreira kada korisnik odabere teren i slobodan termin. Nakon potvrde vlasnika, rezervacija postaje aktivna. Po dolasku korisnika i početku korišćenja terena prelazi u stanje „U toku“, a nakon isteka termina u stanje „Završena“.

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
| Backoffice         | vlasnici objekata, administratori | Flutter           | Windows, veb   |
| Javni veb          | svi posetioci                     | Jaspr             | pregledač      |
| Server             | ostali delovi sistema             | Relic, PostgreSQL | Linux, Windows |
| Domenski paket     | svi delovi sistema                | Dart              | sve            |
