import 'package:flutter/widgets.dart'; // For ValueNotifier, debugPrint
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:convert/convert.dart'; // For hex.decode
import 'dart:typed_data'; // For Uint8List

class MeshService {
  // UUIDs for Bull Mesh Service
  // Using a custom 128-bit UUID for the service
  static const String _serviceUuid = "B011-MESH-0000-0000-0000-000000000000"; 
  static const String _txCharacteristicUuid = "TX00-DATA-0000-0000-0000-000000000000";

  bool _isAdvertising = false;
  
  // State Notifiers
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false); // For UI Lock-on animation

  // Stream to expose found transactions to the app
  final _transactionController = StreamController<String>.broadcast();
  Stream<String> get incomingTransactions => _transactionController.stream;

  Future<void> startAdvertising(String txHex) async {
    if (_isAdvertising) return;
    
    await _checkPermissions();

    // Check bluetooth is on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is not enabled');
    }

    try {
      _isAdvertising = true;
      
      // Define the Characteristic (Read-Only)
      final txBytes = hex.decode(txHex);
      final characteristic = BleCharacteristic(
        uuid: _txCharacteristicUuid,
        properties: [
          CharacteristicProperties.read,
          CharacteristicProperties.notify, 
        ],
        permissions: [
          AttributePermissions.readable,
        ],
        value: Uint8List.fromList(txBytes), // Set static value here for reliability
      );

      // Define the Service
      final service = BleService(
        uuid: _serviceUuid,
        primary: true,
        characteristics: [characteristic],
      );

      // Add Service to the Peripheral
      // Note: Implementation details of addService depend on the specific version of flutter_ble_peripheral API
      // Checking docs or assuming standard usage:
      await FlutterBlePeripheral().addService(service);

      // Configure the advertisement bundle
      final AdvertiseData advertiseData = AdvertiseData(
        serviceUuid: _serviceUuid,
        includeDeviceName: true,
        localName: 'BullMesh',
      );

      // Start advertising
      await FlutterBlePeripheral().start(advertiseData: advertiseData);
      
      // Update the Characteristic Value with the Tx Hex
      // This allows the connected central to read the transaction
      final txBytes = hex.decode(txHex);
      
      // Implementation Note: We set the characteristic value at initialization (in the constructor above).
      // This "Immutable Service" approach is more stable for v2 than dynamic updates via writeCharacteristic.
       
      debugPrint('Started BLE advertising and Server for Tx: \${txHex.substring(0, 10)}... (Length: \${txBytes.length} bytes)');
    } catch (e) {
      _isAdvertising = false;
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    isConnectedNotifier.value = false;
    await FlutterBlePeripheral().stop();
  }

  Future<void> startScanningForRelay() async {
    if (isScanningNotifier.value) return;

    await _checkPermissions();
    
    // if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
    //   throw Exception('Bluetooth is not enabled');
    // }

    isScanningNotifier.value = true;
    
    // Start scanning for devices with our Service UUID
    await FlutterBluePlus.startScan(
      withServices: [Guid(_serviceUuid)],
      timeout: const Duration(seconds: 15),
    );

      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          // Check for our Service UUID in advertisement
          if (r.advertisementData.serviceUuids.contains(Guid(_serviceUuid))) {
             debugPrint('Mesh: Found Bull Mesh peer: ${r.device.remoteId}');
             
             try {
                // 1. Connect to the device to read the GATT data
                // Note: autoConnect: false is usually better for immediate non-persistent connections
                await r.device.connect(autoConnect: false);
                
                // 2. Discover Services
                List<BluetoothService> services = await r.device.discoverServices();
                BluetoothService? meshService;
                try {
                  meshService = services.firstWhere((s) => s.uuid == Guid(_serviceUuid));
                } catch (e) {
                   debugPrint('Mesh: Service not found on device');
                }

                if (meshService != null) {
                  // 3. Find the Characteristic
                  BluetoothCharacteristic? txChar;
                  try {
                    txChar = meshService.characteristics.firstWhere((c) => c.uuid == Guid(_txCharacteristicUuid));
                  } catch (e) {
                    debugPrint('Mesh: Characteristic not found');
                  }

                  if (txChar != null) {
                     // 4. Read the Value (The Transaction)
                     List<int> value = await txChar.read();
                     String txHex = hex.encode(value);
                     
                     debugPrint('Mesh: Read Payload (${value.length} bytes): ${txHex.substring(0, 10)}...');

                     // 5. Validate & Relay
                     if (isValidTxHex(txHex)) {
                       _transactionController.add(txHex);
                       debugPrint('Mesh: Valid Tx received. Queued for Relay.');
                     } else {
                        debugPrint('Mesh: Dropped invalid packet.');
                     }
                  }
                }
                
                // 6. Disconnect
                await r.device.disconnect();
                
             } catch (e) {
                debugPrint('Mesh: Error during handshake/read: $e');
                // Ensure disconnect happens even on error
                try { await r.device.disconnect(); } catch (_) {}
             }
          }
        }
      }
      
      await device.disconnect();
    } catch (e) {
      print("Error connecting to mesh peer: \$e");
    }
  }

  /// Public static method for easier Unit Testing of security logic
  static bool isValidTxHex(String txHex) {
     // A valid Bitcoin Tx is only Hex characters (0-9, A-F)
     // And generally has a reasonable minimal length (e.g. > 20 chars for a very basic tx)
     final validHex = RegExp(r'^[0-9a-fA-F]+$');
     return validHex.hasMatch(txHex) && txHex.length > 20;
  }

  Future<void> stopScanning() async {
    isScanningNotifier.value = false;
    await FlutterBluePlus.stopScan();
  }
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location, // Often required for BLE scanning on Android
    ].request();

    if (statuses.values.any((status) => status.isDenied || status.isPermanentlyDenied)) {
      throw Exception('Bluetooth & Location permissions are required for Bull Mesh');
    }
  }
}
