# session_storage

Gde se čuva token prijave između pokretanja aplikacije. Implementira port `SessionStore` iz `api_client`
(`read`, `write`, `clear`), pa se skladište menja bez izmene `ApiClient`-a, `AuthBloc`-a i ekrana.
Flutter paket: koriste ga mobilna aplikacija i backoffice.

| Platforma | Gde se čuva token | Klasa |
| --------- | ----------------- | ----- |
| Android | Keystore (preko `flutter_secure_storage`) | `SecureKeyValueStorage` |
| iOS, macOS | Keychain | `SecureKeyValueStorage` |
| Windows | Credential Manager | `SecureKeyValueStorage` |
| Linux | libsecret | `SecureKeyValueStorage` |
| Veb | `localStorage` pregledača | `BrowserKeyValueStorage` |

`createSessionStore()` bira skladište za platformu; sve se vodi preko `KeyValueSessionStore`, koji drži jedan ključ
(`terenzo_session`) i ne ruši aplikaciju kada skladište ne radi.

```dart
final session = createSessionStore();
final api = ApiClient(baseUri: serverUri, session: session);
```

## Pravila

- Čuva se samo **token**, nikad lozinka (proverava test sa `HttpSessionRepository`).
- Prijava ostaje posle ponovnog pokretanja aplikacije i posle osvežavanja stranice, a briše se odjavom (`clear`).
  Vreme isteka određuje server: istekao token klijent briše sam (`ApiClient`, `token_expired`).
- Skladište koje ne radi (privatni prozor, oštećen Keystore) ne sme da sruši aplikaciju: čitanje daje `null`
  (korisnik se prijavljuje ponovo), a upis koji ne uspe znači samo da se prijava ne pamti posle zatvaranja.

## Veb: izbor i kompromis

Na vebu nema bezbednog skladišta platforme. Token ide u `localStorage` jer mora da preživi osvežavanje stranice
(memorija ne bi) i zatvaranje pregledača do isteka na serveru. Skripta sa iste adrese (XSS) može da ga pročita,
pa je ovo slabije od Keystore-a ili Keychain-a. Ublažava ga to što token ističe na serveru.

Odbačeno: *`sessionStorage`* (nestaje sa zatvaranjem taba, korisnik se stalno prijavljuje), *kolačić* (traži
`Access-Control-Allow-Credentials` i CSRF zaštitu; odluka 10 u `docs/kt2-decisions.md`), *šifrovanje ključem iz istog
`localStorage`-a* (`flutter_secure_storage` na vebu) jer ne štiti od skripte koja čita i ključ.

## Testovi

```sh
cd packages/session_storage
flutter test                                              # VM: logika, adapter za bezbedno skladište
dart test -p chrome test/browser_key_value_storage_test.dart   # pravi localStorage u Chrome-u
```

Sam Keychain, Keystore, Credential Manager i libsecret se ne mogu proveriti iz testa, već samo na uređaju.
