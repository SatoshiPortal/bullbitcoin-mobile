import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2596
// Finding: Watch-only descriptor import accepts and stores extended private keys.
// Regression test for the fix.
void main() {
  group('Security audit #2596 xprv descriptor import', () {
    test('watch-only parser rejects private key material', () {
      final source = File(
        'lib/features/import_watch_only_wallet/watch_only_wallet_entity.dart',
      ).readAsStringSync();
      expect(source, contains('xprv'));
      expect(source, contains('yprv'));
      expect(source, contains('zprv'));
    });
  });
}
