// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2656
// Finding: Electrum reads have no bounded timeout after connection.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2656 Electrum read timeout', () {
    test('first response has a bounded read timeout', () {
      final source = File(
        'lib/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart',
      ).readAsStringSync();
      expect(
        source,
        contains('final firstLine = await lines.first.timeout(timeout);'),
      );
    });
  });
}
