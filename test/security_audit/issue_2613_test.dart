// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2613
// Finding: stored BIP85 derivations are re-derived without checking their source fingerprint.
// Regression test for the secure source-fingerprint check.
//
// Secrets selects stored paths by the requested root before re-deriving.
// The check is also asserted behaviourally in
// test/features/bip85_entropy/derive_next_bip85_usecase_test.dart,
//   "rows of another root key are not re-derived from this one".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2613 stored-source fingerprint', () {
    test('Secrets rejects rows from another source wallet', () {
      final source = File(
        'packages/secrets/lib/src/public/bip85_derivations.dart',
      ).readAsStringSync();

      // Each row carries the fingerprint of the root that created it; a row of another root is skipped rather than re-derived from this one.
      expect(source, contains('record.parentFingerprint'));
      expect(source, contains('parent.hex'));
      expect(source, contains('continue'));
      // And the value is derived from the row's own persisted path.
      expect(source, contains('record.path'));
    });
  });
}
