// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2634
// Finding: mnemonic import persists a seed before wallet creation can succeed,
// and an orphaned seed then blocks every retry through the duplicate check.
// Regression test for the fix.
//
// The symbols moved when the seed layer became `package:secrets` — `createFromMnemonic` is `Secrets.import`, `_seedRepository.delete` is `_secrets.trash` — so the source strings below were updated with them. The property itself is now also asserted behaviourally, against a real keystore, which is the stronger check:
//   test/features/import_mnemonic/domain/import_wallet_usecase_test.dart
//     "a secret this import created is removed when the wallet cannot be built"
//     "a secret that was already stored survives a failed import"
//   test/security_audit/behavior/import_wallet_seed_cleanup_test.dart (all three)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2634 orphaned mnemonic seed', () {
    test('failed wallet creation removes the persisted secret', () {
      final source = File(
        'lib/features/import_mnemonic/domain/import_wallet_usecase.dart',
      ).readAsStringSync();

      // The secret is stored before the wallet is built — that ordering is what creates the orphan — so the cleanup path must exist.
      expect(
        source.indexOf('_secrets.import'),
        lessThan(source.indexOf('createWallet')),
      );
      expect(source, contains('_secrets.trash'));
      // And it deletes only what this import created.
      expect(source, contains('seedCreatedByThisImport'));
    });

    test('duplicate check remains separate from cleanup', () {
      final source = File(
        'lib/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('_secrets.exists(id)'));
      expect(source, isNot(contains('trash')));
    });
  });
}
