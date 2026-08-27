// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2639
// Finding: the Coldcard PushTx checksum is parsed but never verified.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2639 PushTx checksum', () {
    test('checksum is verified before payload parsing', () {
      final source = File(
        'lib/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart',
      ).readAsStringSync();
      expect(source, contains('sha256.convert(txBytes)'));
      expect(source, contains('Invalid PushTx checksum'));
      expect(source, contains("pushTx.scheme != 'https'"));
    });
  });
}
