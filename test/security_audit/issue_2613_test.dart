// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2613
// Finding: stored BIP85 derivations are re-derived without checking their source fingerprint.
// Regression test for the secure source-fingerprint check.
//
// The re-derivation moved into `package:secrets` — the xprv no longer leaves it — so the usecase now fetches a `Secret` and compares `secret.id` rather than deriving an xprv and comparing its fingerprint. The check is the same one; its spelling changed. It is also asserted behaviourally in
// test/core_test/bip85/derive_next_bip85_usecase_test.dart,
//   "rows of another root key are not re-derived from this one".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2613 stored-source fingerprint', () {
    test('fetch usecase rejects rows from another source wallet', () {
      final source = File(
        'lib/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart',
      ).readAsStringSync();

      // Each row carries the fingerprint of the root that created it; a row of another root is skipped rather than re-derived from this one.
      expect(source, contains('e.xprvFingerprint'));
      expect(source, contains('secret.id.hex'));
      expect(source, contains('continue'));
      // And the value is derived from the row's own persisted path.
      expect(source, contains('e.path'));
    });
  });
}
