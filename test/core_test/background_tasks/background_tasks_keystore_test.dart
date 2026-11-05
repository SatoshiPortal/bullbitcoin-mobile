import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WorkManager isolate builds its own `Secrets`, and the package's write
/// lock is per isolate. That is safe only while no background task mutates
/// the keystore — which is true today, and this keeps it true: adding a task
/// that imports, trashes or repairs a secret must first fail here and be
/// argued for in review, not discovered as a lost write in the field.
void main() {
  group('background tasks stay out of the keystore', () {
    test('the task set is exactly the five read-only ones', () {
      // wallets-sync replaces bitcoin-sync and liquid-sync; the legacy names
      // stay so runs scheduled by the previous version still complete.
      expect(
        BackgroundTask.values.map((t) => t.name),
        unorderedEquals([
          'wallets-sync',
          'bitcoin-sync',
          'liquid-sync',
          'swaps-sync',
          'logs-prune',
        ]),
      );
    });

    test('the handler reaches no secret-mutating use case', () {
      // The handler is split between the WorkManager entry point and the
      // background composition root that builds the task graph.
      for (final path in [
        'lib/background_entrypoint.dart',
        'lib/background_bootstrap.dart',
      ]) {
        final source = File(path).readAsStringSync();

        expect(source, isNot(contains('package:secrets')), reason: path);
        for (final mutating in [
          'ImportWalletUsecase',
          'CreateDefaultWalletsUsecase',
          'DeleteWalletUsecase',
          'DeleteStoredWalletUsecase',
          'DeleteSecretUsecase',
          'RestoreVaultUsecase',
          'CreateEncryptedVaultUsecase',
          '.recoverbull.restore(',
          '.trash(',
          '.import(',
          '.generate(',
        ]) {
          expect(source, isNot(contains(mutating)), reason: '$path: $mutating');
        }
      }
    });

    test('the task package cannot reach the keystore', () {
      // The tasks themselves now live in packages/background_tasks; without a
      // dependency on secrets they cannot touch it.
      final pubspec = File(
        'packages/background_tasks/pubspec.yaml',
      ).readAsStringSync();

      expect(pubspec, isNot(matches(RegExp(r'^\s+secrets:', multiLine: true))));
    });
  });
}
