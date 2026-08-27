// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2649
// Finding: the referenced BitBox Rust dependency source is not locally available.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2649 P2WSH signing', () {
    test('Rust dependency is not vendored in the checkout', () {
      final lock = File('pubspec.lock').readAsStringSync();
      expect(lock, contains('https://github.com/SatoshiPortal/bull_sdk'));
      expect(Directory('packages/bitbox-transport').existsSync(), isFalse);
    });
  });
}
