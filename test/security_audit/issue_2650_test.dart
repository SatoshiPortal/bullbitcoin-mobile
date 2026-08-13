// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2650
// Finding: device errors were classified by ad-hoc English substring matching,
// so device-side cancellation degraded to a generic unexpected failure.
// Regression test for the fix: patterns live in one explicit table that maps
// cancellation and pairing rejection to a dedicated failure.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2650 error classification', () {
    test('error patterns are centralized and cover device cancellation', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();

      expect(source, contains('_errorPatterns'));
      // Device-side cancellation and pairing rejection map to the dedicated
      // cancellation failure instead of an unexpected one.
      expect(source, contains("'user abort'"));
      expect(source, contains("'pairing rejected'"));
      expect(
        source,
        contains("('user abort', OperationCancelledBitBoxFailure())"),
      );
    });
  });
}
