// Runs the encryption in a process of its own and SIGKILLs that process when it reaches a given step, as the OS kills an app: no unwinding, no `finally`.
//
// Usage: dart run test/support/encrypt_and_die.dart <path> <keySeed> <step|never>
import 'dart:io';

import 'package:bull_sqlite/src/encrypt_in_place.dart';
import 'package:bull_sqlite/src/sqlite_family.dart';

import 'fixtures.dart';

void main(List<String> args) {
  final path = args[0];
  final key = keyOf(int.parse(args[1]));
  final target = args[2];
  encryptInPlace(
    SqliteFamily(path),
    key,
    onStep: (step) {
      if (step.name == target) Process.killPid(pid, ProcessSignal.sigkill);
    },
  );
  stdout.writeln('completed');
}
