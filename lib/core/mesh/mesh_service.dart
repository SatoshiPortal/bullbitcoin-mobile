import 'package:flutter/widgets.dart'; // For ValueNotifier, debugPrint
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

class MeshService {
  // UUIDs for Bull Mesh Service
  // Using a custom 128-bit UUID for the service
  static const String _serviceUuid = "B011-MESH-0000-0000-0000-000000000000"; 
  static const String _txCharacteristicUuid = "TX00-DATA-0000-0000-0000-000000000000";

  bool _isAdvertising = false;
  
  // Notifier for scanning state
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);

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
      
      // Configure the advertisement bundle
      final AdvertiseData advertiseData = AdvertiseData(
        serviceUuid: _serviceUuid,
        includeDeviceName: true,
        localName: 'BullMesh',
      );

      // Start advertising
      await FlutterBlePeripheral().start(advertiseData: advertiseData);
      
      debugPrint('Started BLE advertising for Tx: \${txHex.substring(0, 10)}...');
    } catch (e) {
      _isAdvertising = false;
      rethrow;
    }
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
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

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        _connectAndRead(result.device);
      }
    });
  }

  Future<void> _connectAndRead(BluetoothDevice device) async {
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toUpperCase() == _serviceUuid) {
          for (var characteristic in service.characteristics) {
             if (characteristic.uuid.toString().toUpperCase() == _txCharacteristicUuid) {
                // Read the Tx
                List<int> value = await characteristic.read();
                String txHex = String.fromCharCodes(value);
                
                // Security/Sanity Check: Ensure it looks like a valid Hex string
                if (isValidTxHex(txHex)) {
                  _transactionController.add(txHex);
                } else {
                  debugPrint('Mesh: Ignored invalid/garbage data: \${txHex.length > 20 ? txHex.substring(0,10) : txHex}');
                }
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
