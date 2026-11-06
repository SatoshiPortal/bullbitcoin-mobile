// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2634
// Finding: mnemonic import persists a seed before wallet creation can succeed,
// and an orphaned seed then blocks every retry through the duplicate check.
// Regression test for the fix.
//
// Single-writer provisioning (2026-11-06) preserves the secret and catalog row
// after failure so startup can resume. Automatic orphan cleanup is no longer
// safe: a native failure can follow a committed catalog entry. Behavioral
// coverage lives in import_wallet_seed_cleanup_test.dart and the wallet runtime
// provisioning tests.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2634 orphaned mnemonic seed', () {
    test('failed wallet creation preserves custody for provisioning retry', () {
      final source = File(
        'lib/features/import_mnemonic/domain/import_wallet_usecase.dart',
      ).readAsStringSync();

      // A committed catalog entry may already refer to the imported secret.
      expect(
        source.indexOf('_secrets.import'),
        lessThan(source.indexOf('createWallet')),
      );
      expect(source, isNot(contains('_secrets.trash')));
    });

    test('duplicate check remains separate from cleanup', () {
      final source = File(
        'lib/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('_secrets.contains('));
      expect(source, isNot(contains('trash')));
    });
  });
}
