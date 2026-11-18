/// Gde se čuva token prijave između pokretanja aplikacije.
///
/// Port: `ApiClient` ne zna da li je iza njega bezbedno skladište platforme
/// (Keychain, Keystore, Credential Manager, libsecret), skladište pregledača
/// ili memorija. Implementacije za platforme dolaze u T49. Čuva se samo token,
/// nikad lozinka.
abstract interface class SessionStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Token samo dok aplikacija radi. Za testove i za početak, dok nema
/// skladišta platforme.
final class MemorySessionStore implements SessionStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
