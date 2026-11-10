import 'dart:io';

import 'package:server/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single.isEmpty) {
    stderr.writeln('Upotreba: dart run tool/hash_password.dart "lozinka"');
    exitCode = 64;
    return;
  }
  stdout.writeln(await hashPassword(arguments.single));
}
