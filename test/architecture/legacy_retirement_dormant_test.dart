import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// No destructive entry point exists in WS5a. Activation requires a separate
// reviewed change, including the recovery provenance contract.
void main() {
  final roots = ['lib', 'packages', 'features'];

  Iterable<File> sources() sync* {
    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final parts = p.split(entity.path);
        if (parts.contains('test') ||
            parts.contains('.dart_tool') ||
            parts.contains('build')) {
          continue;
        }
        yield entity;
      }
    }
  }

  test('the retirement implementation has no destructive operations', () {
    final files = [
      'packages/legacy_storage/lib/src/coordinator.dart',
      'packages/legacy_storage/lib/src/retirement.dart',
      'packages/secrets/lib/src/data/legacy_retirement.dart',
      'packages/exchange/lib/src/data/storage/exchange_credential_retirement.dart',
      'features/recoverbull/lib/src/data/database/recoverbull_retirement.dart',
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('LegacyRetirementActivation')), reason: path);
      expect(text, isNot(contains('deleteLegacyEntries')), reason: path);
      expect(text, isNot(contains('.deleteSync(')), reason: path);
      expect(
        text,
        isNot(contains('Future<Result<void, LegacyImportFailure>> retire(')),
        reason: path,
      );
    }
  });

  test('no production code calls the destructive retirement', () {
    final offenders = [
      for (final file in sources())
        if (!file.path.endsWith(
              'packages/legacy_storage/lib/src/coordinator.dart',
            ) &&
            RegExp(r'\.retire\s*\(').hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('no production code calls the retirement diagnostic', () {
    final offenders = [
      for (final file in sources())
        if (RegExp(r'\.evaluateRetirement\s*\(')
            .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('the shell composes no retirement participant', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            RegExp(
              r'retirementParticipants|SecretsRetirement|'
              r'ExchangeCredentialRetirement|RecoverBullRetirement',
            ).hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
