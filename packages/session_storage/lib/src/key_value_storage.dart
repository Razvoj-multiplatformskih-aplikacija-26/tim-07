/// Najmanje što treba da zna skladište: jedan tekst po ključu.
///
/// Iza njega je bezbedno skladište platforme, skladište pregledača ili memorija.
/// `KeyValueSessionStore` ne zna koje.
abstract interface class KeyValueStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Samo dok aplikacija radi. Za testove.
final class MemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
