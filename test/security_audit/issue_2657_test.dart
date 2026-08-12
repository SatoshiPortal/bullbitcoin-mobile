import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2657
// Finding: Dio uses its default redirect behavior without revalidating targets.
// Regression test for the fix.
void main() {
  group('Security audit #2657 fee redirects', () {
    test('fee client disables redirects', () {
      final source = File(
        'lib/core/fees/data/fees_datasource.dart',
      ).readAsStringSync();
      expect(source, contains('followRedirects: false'));
      expect(source, contains('validateStatus'));
    });
  });
}
