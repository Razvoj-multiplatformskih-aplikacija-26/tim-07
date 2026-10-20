import 'package:flutter/material.dart';

abstract final class BackofficeTheme {
  static const Color primaryColor = Color(0xFF2E7D32);

  static final ThemeData lightTheme = _build(Brightness.light);

  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
      ),
    );
  }
}
