// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2649
// Finding: the referenced BitBox Rust dependency source is not locally available.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2649 P2WSH signing', () {
    // The BitBox binding crate now lives in packages/rust_bindings; the
    // `todo!()` of `script_config_from_utxo` is in bitbox-api-rs, still an
    // external git dependency of that crate.
    test('Rust dependency is not vendored in the checkout', () {
      final lock = File('packages/rust_bindings/rust/Cargo.lock')
          .readAsStringSync();
      expect(
        lock,
        contains('git+https://github.com/ben-kaufman/bitbox-api-rs'),
      );
      expect(Directory('packages/bitbox-api-rs').existsSync(), isFalse);
    });
  });
}
