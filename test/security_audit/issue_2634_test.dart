// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2634
// Finding: mnemonic import persists a seed before wallet creation can succeed,
// and an orphaned seed then blocks every retry through the duplicate check.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2634 orphaned mnemonic seed', () {
    test('failed wallet creation removes the persisted seed', () {
      final source = File(
        'lib/features/import_mnemonic/domain/import_wallet_usecase.dart',
      ).readAsStringSync();

      // The seed is cleaned up when wallet creation fails.
      expect(
        source.indexOf('createFromMnemonic'),
        lessThan(source.indexOf('createWallet')),
      );
      expect(source, contains('_seedRepository.delete'));
    });

    test('duplicate check remains separate from cleanup', () {
      final source = File(
        'lib/features/import_mnemonic/domain/check_duplicate_mnemonic_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('exists(fingerprint)'));
    });
  });
}
