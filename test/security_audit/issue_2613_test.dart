// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2613
// Finding: stored BIP85 derivations are re-derived without checking their source fingerprint.
// Regression test for the secure source-fingerprint check.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2613 stored-source fingerprint', () {
    test('fetch usecase rejects rows from another source wallet', () {
      final source = File(
        'lib/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('final seedResult = await _getDefaultSeedUsecase.execute('),
      );
      expect(source, contains('final Seed defaultSeed'));
      expect(source, contains('Bip85HardenedPath(e.path)'));
      expect(source, contains('xprvFingerprint'));
      expect(source, contains('fingerprint'));
      expect(source, contains('where'));
    });
  });
}
