@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Klijent mora da radi i u pregledaču, pa ne sme da uvozi `dart:io`
/// (ni Flutter, ni pakete koji ih traže).
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('paket ima izvorne fajlove', () {
    expect(sources, isNotEmpty);
  });

  test('nijedan fajl ne uvozi dart:io, dart:ffi ni Flutter', () {
    final forbidden = RegExp(
      r'''import\s+['"](package:flutter[/'"]|dart:(io|ffi|html|js_interop))''',
    );

    for (final file in sources) {
      expect(
        forbidden.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path} uvozi zabranjen paket',
      );
    }
  });

  test('zavisi od ugovora i domena, ne od servera ni od aplikacija', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final forbidden in ['server', 'blocs', 'mobile', 'backoffice']) {
      expect(
        RegExp('^  $forbidden:', multiLine: true).hasMatch(pubspec),
        isFalse,
        reason: forbidden,
      );
    }
  });
}
