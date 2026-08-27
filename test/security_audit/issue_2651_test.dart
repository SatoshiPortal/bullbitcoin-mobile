// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2651
// Finding: disposal disconnects but does not cancel an in-flight operation.
// This test PASSES while the vulnerability exists: it documents the current
// vulnerable behavior. When the issue is fixed, flip the assertions to the
// secure behavior so this becomes a regression test.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2651 abandoned operations', () {
    test('datasource has no operation cancellation in disposal path', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();
      final dispose = source.substring(
        source.indexOf('Future<void> dispose()'),
      );
      expect(dispose, contains('_bleConnector.stopScan()'));
      expect(dispose, isNot(contains('cancel')));
      expect(source, contains('Duration(seconds: 20)'));
    });
  });
}
