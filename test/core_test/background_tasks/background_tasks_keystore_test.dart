import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

/// The headless graph must never instantiate or mutate custody capabilities.
void main() {
  group('background tasks stay out of the keystore', () {
    test(
      'the task set contains only wallet sync and legacy cancellation names',
      () {
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
      },
    );

    test('the handler reaches no secret-mutating use case', () {
      final source = [
        'lib/background_bootstrap.dart',
        'lib/features/wallet/background_setup.dart',
        'lib/features/electrum_settings/background_setup.dart',
      ].map((path) => File(path).readAsStringSync()).join('\n');

      expect(source, isNot(contains('package:secrets')));
      for (final mutating in [
        'ImportWalletUsecase',
        'CreateDefaultWalletsUsecase',
        'DeleteWalletUsecase',
        'DeleteSecretUsecase',
        'RestoreVaultUsecase',
        'CreateEncryptedVaultUsecase',
        '.recoverbull.restore(',
        '.trash(',
        '.import(',
        '.generate(',
      ]) {
        expect(source, isNot(contains(mutating)), reason: mutating);
      }
    });
  });
}
