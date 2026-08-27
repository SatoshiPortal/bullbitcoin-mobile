// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2652
// Finding: BLE discovery anchored its settle window to the first advertiser
// and hard-failed on more than one device.
// Regression test for the fix: the settle window restarts on every newly
// discovered advertiser.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Security audit #2652 BLE discovery', () {
    test('settle window restarts on every new advertiser', () {
      final source = File(
        'lib/core/bitbox/data/datasources/bitbox_device_datasource.dart',
      ).readAsStringSync();

      final start = source.indexOf('_scanBleDevicesForDuration');
      final end = source.indexOf('_ensureBleTransportReady', start);
      final scan = source.substring(start, end);

      // Every new device cancels and rearms the settle timer instead of
      // inheriting the first advertiser's window.
      expect(scan, contains('settleTimer?.cancel();'));
      expect(scan, contains('settleTimer = Timer(settle,'));
      // The upstream first-device-anchored call is gone.
      expect(scan, isNot(contains('_bleConnector.scanDevices')));
    });
  });
}
