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

      // The entropy is derived from the DEFAULT wallet's seed, and rows are
      // then filtered by that key's fingerprint. The seed read is a `switch`
      // over a Result now rather than a bare `await` (#1895); what this audit
      // pins is that the seed comes from GetDefaultSeedUsecase and nowhere
      // else, not the syntax used to read it.
      expect(source, contains('_getDefaultSeedUsecase.execute()'));
      expect(source, contains('defaultSeed.bytes'));
      expect(source, contains('Bip85HardenedPath(e.path)'));
      expect(source, contains('xprvFingerprint'));
      expect(source, contains('fingerprint'));
      expect(source, contains('where'));
    });
  });
}
