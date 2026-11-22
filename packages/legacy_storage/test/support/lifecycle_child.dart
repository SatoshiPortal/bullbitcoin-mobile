import 'dart:io';

import 'package:legacy_storage/coordination.dart';

Future<void> main(List<String> args) async {
  final gate = NativeFileGate(File(args[0]));
  try {
    final admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    );
    stdout.writeln('acquired');
    await stdin.first;
    await admission.close();
  } on LifecycleException {
    stdout.writeln('busy');
  }
}
