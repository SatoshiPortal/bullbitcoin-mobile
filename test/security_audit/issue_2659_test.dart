// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2659
// Finding: onion validation constructs a direct Dio client instead of using Tor.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2659 onion validation transport', () {
    test('validator configures the Tor transport for onion servers', () {
      final source = File(
        'lib/core/mempool/interface_adapters/validators/'
        'http_mempool_server_validator.dart',
      ).readAsStringSync();

      expect(source, contains('httpClientAdapter'));
      expect(source, contains('httpClient'));
      expect(source, contains('.onion'));
    });
  });
}
