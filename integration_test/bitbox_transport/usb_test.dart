import 'dart:io' show Platform;

import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:rust_bindings/bitbox.dart' as bitbox;
import 'package:rust_bindings/rust_bindings.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration test for BitBox02 USB connection.
/// Requires: Android device with BitBox02 connected via USB-C/OTG.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('USB Connector', () {
    setUpAll(() async {
      await BullSdk.init();
    });

    testWidgets('scan for USB devices', (tester) async {
      if (!Platform.isAndroid) {
        markTestSkipped('USB only supported on Android');
        return;
      }

      final devices = await BitBoxApi.scanDevices();
      expect(devices, isA<List<BitBox02Device>>());
      debugPrint('Found ${devices.length} USB device(s)');
      for (final device in devices) {
        debugPrint('  - ${device.product} (${device.serialNumber})');
      }
    });

    testWidgets('connect and get root fingerprint via USB', (tester) async {
      if (!Platform.isAndroid) {
        markTestSkipped('USB only supported on Android');
        return;
      }

      // Scan
      final devices = await BitBoxApi.scanDevices();
      if (devices.isEmpty) {
        markTestSkipped('No BitBox02 USB device found');
        return;
      }

      final device = devices.first;
      debugPrint('Connecting to ${device.product} (${device.serialNumber})...');

      // Request permission
      final permitted = await BitBoxApi.requestPermission(device.deviceName);
      expect(permitted, isTrue);

      // Open device
      final opened = await BitBoxApi.openDevice(
        device.deviceName,
        device.serialNumber,
      );
      expect(opened, isTrue);

      // Start pairing
      final pairingCode = await BitBoxApi.startPairing(device.serialNumber);
      debugPrint('Pairing code: $pairingCode');
      // User must confirm on device...

      if (pairingCode != null) {
        debugPrint('Please confirm pairing on BitBox02...');
        final confirmed = await BitBoxApi.confirmPairing(device.serialNumber);
        expect(confirmed, isTrue);

        // Get root fingerprint
        final fingerprint = await BitBoxApi.getRootFingerprint(
          device.serialNumber,
        );
        expect(fingerprint, isNotEmpty);
        debugPrint('Root fingerprint: $fingerprint');

        // Get device info
        final info = await bitbox.getDeviceInfo(
          serialNumber: device.serialNumber,
        );
        debugPrint(
          'Device: ${info.name} v${info.version} (initialized: ${info.initialized})',
        );
      }

      // Cleanup
      await BitBoxApi.closeDevice(device.serialNumber);
      debugPrint('Device closed');
    });
  });
}
