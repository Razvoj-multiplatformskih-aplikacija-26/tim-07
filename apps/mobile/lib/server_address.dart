import 'package:flutter/foundation.dart';

/// Adresa servera, bez ijedne izmene koda.
///
/// Zadaje se pri pokretanju: `flutter run --dart-define=SERVER_URL=http://192.168.0.5:8080`.
/// Kada nije zadata, uzima se adresa koja radi na tom uređaju:
/// - Android emulator vidi računar na `10.0.2.2` (njegov `localhost` je emulator);
/// - ostalo (simulator, desktop, veb) vidi server na `localhost`.
///
/// Pravi telefon sa USB kablom: `adb reverse tcp:8080 tcp:8080`, pa `localhost`
/// radi i tamo (`--dart-define=SERVER_URL=http://localhost:8080`).
Uri serverAddress({
  String configured = const String.fromEnvironment('SERVER_URL'),
  TargetPlatform? platform,
  bool? isWeb,
}) {
  if (configured.isNotEmpty) return Uri.parse(configured);

  final onAndroid =
      !(isWeb ?? kIsWeb) &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  return Uri.parse(onAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080');
}
