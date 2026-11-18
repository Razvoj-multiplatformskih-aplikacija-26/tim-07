import 'dart:io';

import 'package:test/test.dart';

/// Ugovor mora da radi svuda gde radi Dart: u pregledaču, na telefonu i na serveru.
/// Zato ne sme da uvozi domen, Flutter ni ništa što traži `dart:io`.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('paket ima izvorne fajlove', () {
    expect(sources, isNotEmpty);
  });

  test('nijedan fajl ne uvozi domain, Flutter, dart:io ni dart:ffi', () {
    final forbidden = RegExp(
      r'''import\s+['"](package:(domain|mapping|api_client|blocs|flutter)[/'"]|dart:(io|ffi|html|js_interop))''',
    );

    for (final file in sources) {
      expect(
        forbidden.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '${file.path} uvozi zabranjen paket',
      );
    }
  });

  test('pubspec nema zavisnosti osim razvojnih', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      RegExp(r'^dependencies:', multiLine: true).hasMatch(pubspec),
      isFalse,
    );
    expect(pubspec, isNot(contains('domain')));
    expect(pubspec, isNot(contains('flutter')));
  });
}
