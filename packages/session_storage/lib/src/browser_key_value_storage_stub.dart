import 'key_value_storage.dart';

/// Skladište pregledača. Postoji samo u pregledaču; na ostalim platformama
/// se koristi [SecureKeyValueStorage].
final class BrowserKeyValueStorage implements KeyValueStorage {
  BrowserKeyValueStorage() {
    throw UnsupportedError('Skladište pregledača postoji samo na vebu.');
  }

  @override
  Future<String?> read(String key) => throw UnimplementedError();

  @override
  Future<void> write(String key, String value) => throw UnimplementedError();

  @override
  Future<void> delete(String key) => throw UnimplementedError();
}
