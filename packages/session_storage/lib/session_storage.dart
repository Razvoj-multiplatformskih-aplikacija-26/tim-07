// Terenzo - gde se čuva token prijave između pokretanja aplikacije.
//
// Implementacije porta `SessionStore` iz `api_client`: bezbedno skladište
// platforme (Keychain, Keystore, Credential Manager, libsecret) i skladište
// pregledača. Lozinka se nikad ne čuva, samo token.

export 'src/browser_key_value_storage.dart';
export 'src/create_session_store.dart';
export 'src/key_value_session_store.dart';
export 'src/key_value_storage.dart';
export 'src/secure_key_value_storage.dart';
