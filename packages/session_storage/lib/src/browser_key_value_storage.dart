// Na VM-u (telefon, desktop) skladište pregledača ne postoji.
export 'browser_key_value_storage_stub.dart'
    if (dart.library.js_interop) 'browser_key_value_storage_web.dart';
