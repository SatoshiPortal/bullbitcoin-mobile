// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2615
// Finding: BitBox devices are accepted without cryptographic attestation.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2615 device attestation', () {
    test('connection and pairing contain no attestation verification', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('BitBoxApi.openDevice'));
      expect(source, contains('bitbox.startPairing'));
      expect(source, isNot(contains('attest')));
      expect(source, isNot(contains('attestation')));
    });
  });
}
