// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2622
// Finding: validation accepts any network when the endpoint returns a block height.
// Regression test for the fix.
//
// The behavioural coverage lives in
// test/security_audit/behavior/mempool_network_validation_test.dart, which
// runs the validator against a real HTTP server. This file only pins the
// genesis table so a network can never be silently added without one.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2622 network validation', () {
    test('validation compares the server genesis block', () {
      final source = File(
        'lib/core/mempool/interface_adapters/validators/'
        'http_mempool_server_validator.dart',
      ).readAsStringSync();

      expect(source, contains('required MempoolServerNetwork network'));
      expect(source, contains("const path = '/api/v1/blocks/tip/height'"));
      expect(source, contains('MempoolValidationNetworkMismatchFailure'));
      expect(source, contains('block-height/0'));
      expect(source, contains('_knownGenesisHashes'));
    });
  });
}
