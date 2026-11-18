import 'package:api_client/api_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'browser_key_value_storage.dart';
import 'key_value_session_store.dart';
import 'secure_key_value_storage.dart';

/// Skladište prijave za platformu na kojoj aplikacija radi: skladište
/// pregledača na vebu, a na ostalim platformama bezbedno skladište platforme.
SessionStore createSessionStore() => KeyValueSessionStore(
  kIsWeb ? BrowserKeyValueStorage() : const SecureKeyValueStorage(),
);
