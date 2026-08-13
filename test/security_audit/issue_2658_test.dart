import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2658
// Finding: fee requests construct a direct Dio client without consulting Tor.
// Regression test for the fix.
void main() {
  group('Security audit #2658 fee transport bypasses Tor', () {
    test('fee datasource configures Tor-aware transport', () {
      final source = File(
        'lib/core/fees/data/fees_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('useTorProxy'));
      expect(source, contains('torProxyPort'));
      expect(source, contains('SOCKS5'));
    });
  });
}
