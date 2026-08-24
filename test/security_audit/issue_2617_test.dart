// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2617
// Finding: signed-transaction review opens a direct socket instead of using Tor.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2617 review transport', () {
    test('datasource requires the resolved proxy-aware connection path', () {
      final source = File(
        'lib/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('connection.socks5'));
      expect(source, contains('timeout(timeout)'));
    });
  });
}
