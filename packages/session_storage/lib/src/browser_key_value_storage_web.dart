import 'package:web/web.dart' as web;

import 'key_value_storage.dart';

/// `localStorage` pregledača: prijava ostaje posle osvežavanja stranice i posle
/// zatvaranja pregledača, a server je ipak ukida kada istekne token.
///
/// Token je dostupan skriptama sa iste adrese (XSS), pa je ovo slabije od
/// bezbednog skladišta platforme. Zbog toga token ističe i na serveru, a
/// kolačić nije izabran (odluka 10 u docs/kt2-decisions.md).
final class BrowserKeyValueStorage implements KeyValueStorage {
  BrowserKeyValueStorage();

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem(key);

  @override
  Future<void> write(String key, String value) async =>
      web.window.localStorage.setItem(key, value);

  @override
  Future<void> delete(String key) async =>
      web.window.localStorage.removeItem(key);
}
