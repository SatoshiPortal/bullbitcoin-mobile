// Runs the encryption in a process of its own and SIGKILLs that process when it reaches a given step, as the OS kills an app: no unwinding, no `finally`.
//
// Prints `started` just before the encryption begins, `at:<step>` at every step, and `reached:<step>` just before killing itself, so the parent can prove which point was hit.
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
  stdout.writeln('started');
  encryptInPlace(
    SqliteFamily(path),
    key,
    onStep: (step) {
      // Every step reached, so a timed kill can tell where it landed.
      stdout.writeln('at:${step.name}');
      if (step.name != target) return;
      stdout.writeln('reached:${step.name}');
      Process.killPid(pid, ProcessSignal.sigkill);
      // The signal is asynchronous: never let the encryption go on meanwhile.
      sleep(const Duration(seconds: 30));
    },
  );
  stdout.writeln('completed');
}
