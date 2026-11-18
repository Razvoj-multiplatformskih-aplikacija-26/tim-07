import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_value_storage.dart';

/// Bezbedno skladište platforme: Android Keystore, iOS i macOS Keychain,
/// Windows Credential Manager, Linux libsecret.
final class SecureKeyValueStorage implements KeyValueStorage {
  final FlutterSecureStorage _storage;

  const SecureKeyValueStorage([
    // Data protection keychain traži provisioning profil; običan keychain radi
    // i u nepotpisanim build-ovima.
    this._storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ]);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
