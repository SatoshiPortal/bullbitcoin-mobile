import 'dart:io';

import 'package:path/path.dart' as p;

/// Spawn the Dart VM from the same pinned SDK as the test runner. The tests
/// signal this process directly, so its PID must belong to the VM.
String get dartExecutable {
  final executable = Platform.resolvedExecutable;
  if (p.basenameWithoutExtension(executable) != 'flutter_tester') {
    return executable;
  }

  final cache = p.normalize(p.join(p.dirname(executable), '..', '..', '..'));
  return p.join(
    cache,
    'dart-sdk',
    'bin',
    Platform.isWindows ? 'dart.exe' : 'dart',
  );
}
