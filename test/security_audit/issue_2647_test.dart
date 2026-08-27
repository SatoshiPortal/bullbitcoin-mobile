// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2647
// Finding: pairing failures are converted to an empty optional and misreported.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2647 pairing failure propagation', () {
    test('empty startPairing result is treated as success-like empty code', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('final pairingCode = await bitbox.startPairing'));
      expect(source, contains("return pairingCode ?? '';"));
    });
  });
}
