import 'dart:io';

import 'package:test/test.dart';

/// Testovi paketa ne smeju da zavise od sata računara: rezultat bi tada
/// zavisio od dana i sata kada se pokreću. Vreme se uvek zadaje (fiksiran
/// trenutak ili `clock:` koji Bloc i lažni repozitorijumi primaju).
///
/// Ovaj test čita ostale testove u `packages/` i traži poziv `DateTime.now()`.
/// Widget testovi aplikacija su izuzeti: ekrani koriste pravi sat, pa tamo
/// datumi se računaju od danas, bar dan unapred.
void main() {
  test('testovi paketa ne pozivaju DateTime.now()', () {
    final packages = Directory('..');
    if (!packages.existsSync()) {
      markTestSkipped('Nije pokrenuto iz packages/<paket>.');
      return;
    }

    final offenders = <String>[];
    for (final package in packages.listSync().whereType<Directory>()) {
      final tests = Directory('${package.path}/test');
      if (!tests.existsSync()) continue;

      for (final file in tests.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') ||
            file.path.endsWith('no_real_clock_test.dart')) {
          continue;
        }
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('DateTime.now()')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: 'Testovi sa pravim satom: $offenders');
  });
}
