import 'dart:io';

// A package: import would require depending on bb_mobile, which pulls in native deps (e.g. objective_c) that break `dart run` in this tool's minimal pubspec context.
// ignore: avoid_relative_lib_imports
import '../lib/core/utils/env_validator.dart';

void main() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final file = File('${scriptDir.parent.path}/.env');

  if (!file.existsSync()) {
    stderr.writeln('Error: .env file not found');
    exit(1);
  }

  final env = _parseEnvFile(file.readAsStringSync());
  final errors = EnvValidator.validate(env);

  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('Error: $error');
    }
    stderr.writeln('× .env validation failed');
    exit(1);
  }

  stdout.writeln('✓ .env validation passed');
}

Map<String, String> _parseEnvFile(String content) {
  final result = <String, String>{};

  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final eqIndex = trimmed.indexOf('=');
    if (eqIndex == -1) continue;

    final key = trimmed.substring(0, eqIndex).trim();
    var value = trimmed.substring(eqIndex + 1).trim();

    final commentIndex = value.indexOf(' #');
    if (commentIndex != -1) value = value.substring(0, commentIndex).trim();

    result[key] = value;
  }

  return result;
}
