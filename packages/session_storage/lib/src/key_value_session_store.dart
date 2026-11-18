import 'package:api_client/api_client.dart';

import 'key_value_storage.dart';

/// Čuva token prijave u [KeyValueStorage] pod jednim ključem.
///
/// Skladište koje ne radi (privatni prozor, oštećen Keystore posle povraćaja iz
/// rezervne kopije) ne sme da sruši aplikaciju: čitanje tada daje `null`
/// (korisnik se prijavljuje ponovo), a upis koji ne uspe znači samo da se
/// prijava neće pamtiti posle zatvaranja aplikacije.
final class KeyValueSessionStore implements SessionStore {
  static const defaultKey = 'terenzo_session';

  final KeyValueStorage _storage;

  /// Pod kojim ključem se čuva token.
  final String key;

  const KeyValueSessionStore(this._storage, {this.key = defaultKey});

  @override
  Future<String?> read() async {
    try {
      final token = await _storage.read(key);
      return token == null || token.isEmpty ? null : token;
    } catch (_) {
      // Nečitljiv zapis se briše, da se ne vraća pri svakom pokretanju.
      await _deleteQuietly();
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key, token);
    } catch (_) {
      // Prijava važi dok aplikacija radi, samo se ne pamti.
    }
  }

  @override
  Future<void> clear() => _deleteQuietly();

  Future<void> _deleteQuietly() async {
    try {
      await _storage.delete(key);
    } catch (_) {
      // Odjava ne sme da ostane nedovršena zbog greške skladišta.
    }
  }
}
