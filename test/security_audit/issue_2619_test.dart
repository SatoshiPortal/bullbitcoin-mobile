import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2619
// Finding: the fee HTTP client configures no connection, send, or receive timeout.
// Regression test for the fix.
void main() {
  group('Security audit #2619 fee request timeouts', () {
    test('default Dio builder configures bounded timeouts', () {
      final source = File(
        'lib/core/fees/data/fees_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('connectTimeout:'));
      expect(source, contains('sendTimeout:'));
      expect(source, contains('receiveTimeout:'));
    });
  });
}
