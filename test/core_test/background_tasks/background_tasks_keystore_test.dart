import 'dart:io';

import 'package:bb_mobile/core/background_tasks/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WorkManager isolate builds its own `Secrets`, and the package's write
/// lock is per isolate. That is safe only while no background task mutates
/// the keystore — which is true today, and this keeps it true: adding a task
/// that imports, trashes or repairs a secret must first fail here and be
/// argued for in review, not discovered as a lost write in the field.
void main() {
  group('background tasks stay out of the keystore', () {
    test('the task set is exactly the four read-only ones', () {
      expect(
        BackgroundTask.values.map((t) => t.name),
        unorderedEquals([
          'bitcoin-sync',
          'liquid-sync',
          'swaps-sync',
          'logs-prune',
        ]),
      );
    });

    test('the handler reaches no secret-mutating use case', () {
      final source = File(
        'lib/core/background_tasks/handler.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('package:secrets')));
      for (final mutating in [
        'ImportWalletUsecase',
        'CreateDefaultWalletsUsecase',
        'DeleteWalletUsecase',
        'DeleteSecretUsecase',
        'RestoreVaultUsecase',
        'CreateEncryptedVaultUsecase',
        'repairIdentity',
        '.trash(',
        '.import(',
        '.generate(',
      ]) {
        expect(source, isNot(contains(mutating)), reason: mutating);
      }
    });
  });
}
