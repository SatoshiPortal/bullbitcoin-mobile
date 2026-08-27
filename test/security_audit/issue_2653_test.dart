// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2653
// Finding: the account xpub request always used legacy xpub/tpub version
// bytes regardless of the account's script type.
// Regression test for the fix: the version is selected from the script type.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2653 xpub prefixes', () {
    test('getXpub selects the extended-key version from the script type', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<String> getXpub');
      final end = source.indexOf('Future<String> getMasterFingerprint', start);
      final method = source.substring(start, end);

      expect(method, contains('scriptType.purpose'));
      expect(method, contains("'ypub'"));
      expect(method, contains("'zpub'"));
      expect(method, contains("'upub'"));
      expect(method, contains("'vpub'"));
    });
  });
}
