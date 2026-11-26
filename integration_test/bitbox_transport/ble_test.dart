import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:rust_bindings/bitbox.dart' as bitbox;
import 'package:rust_bindings/rust_bindings.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Integration test for BitBox02 Nova BLE connection.
/// Requires: Android device with BitBox02 Nova nearby and Bluetooth enabled.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('BLE Connector', () {
    setUpAll(() async {
      await BullSdk.init();
    });

    testWidgets('scan for BLE devices', (tester) async {
      debugPrint('Scanning for BitBox02 Nova devices via BLE...');
      final connector = BleConnector();
      final devices = await connector.scanDevices(
        timeout: const Duration(seconds: 10),
      );

      expect(devices, isA<List<BitBox02BleDevice>>());
      debugPrint('Found ${devices.length} BLE device(s)');
      for (final device in devices) {
        debugPrint('  - ${device.name} (${device.deviceId})');
      }
    });

    testWidgets('connect and get root fingerprint via BLE', (tester) async {
      final connector = BleConnector();

      // Scan
      debugPrint('Scanning for BitBox02 Nova...');
      final devices = await connector.scanDevices(
        timeout: const Duration(seconds: 10),
      );

      if (devices.isEmpty) {
        markTestSkipped('No BitBox02 Nova BLE device found');
        return;
      }

      final device = devices.first;
      debugPrint('Connecting to ${device.name} (${device.deviceId})...');

      // Use deviceId as serial number for Rust queue identification
      final serialNumber = device.deviceId;

      final connected = await connector.connect(
        deviceId: device.deviceId,
        serialNumber: serialNumber,
      );
      expect(connected, isTrue);
      debugPrint('Connected!');

      // Read product info
      final productInfo = await connector.readProductInfo();
      debugPrint('Product info: $productInfo');

      // Start pairing via Rust API (same as USB — protocol is identical)
      debugPrint('Starting pairing...');
      final pairingCode = await bitbox.startPairing(serialNumber: serialNumber);
      debugPrint('Pairing code: $pairingCode');

      if (pairingCode != null) {
        debugPrint('Please confirm pairing on BitBox02 Nova...');
        final confirmed = await bitbox.confirmPairing(
          serialNumber: serialNumber,
        );
        expect(confirmed, isTrue);
        debugPrint('Paired!');

        // Get root fingerprint
        final fingerprint = await bitbox.getRootFingerprint(
          serialNumber: serialNumber,
        );
        expect(fingerprint, isNotEmpty);
        debugPrint('Root fingerprint: $fingerprint');

        // Get device info
        final info = await bitbox.getDeviceInfo(serialNumber: serialNumber);
        debugPrint(
          'Device: ${info.name} v${info.version} (initialized: ${info.initialized})',
        );
      }

      // Cleanup
      await connector.disconnect();
      debugPrint('Disconnected');
    });
  });
}
