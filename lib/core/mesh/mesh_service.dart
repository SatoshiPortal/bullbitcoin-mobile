import 'package:flutter/widgets.dart'; // For ValueNotifier, debugPrint
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:convert/convert.dart'; // For hex.decode
import 'dart:typed_data'; // For Uint8List
import 'dart:async'; // For Timer
import 'mesh_protocol.dart';

class MeshService {
  // UUIDs for Bull Mesh Service
  // Using a custom 128-bit UUID for the service
  static const String _serviceUuid = "B011-MESH-0000-0000-0000-000000000000"; 
  static const String _txCharacteristicUuid = "TX00-DATA-0000-0000-0000-000000000000";

  bool _isAdvertising = false;
  Timer? _advertisingLoopTimer;

  
  // State Notifiers
  final ValueNotifier<bool> isScanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false); // For UI Lock-on animation
  final ValueNotifier<double> uploadProgressNotifier = ValueNotifier(0.0); // 0.0 to 1.0
  final ValueNotifier<double> downloadProgressNotifier = ValueNotifier(0.0); // 0.0 to 1.0

  // Stream to expose found transactions to the app
  final _transactionController = StreamController<String>.broadcast();
  Stream<String> get incomingTransactions => _transactionController.stream;

  // Methods to inject events from Background Service (Isolate Bridge)
  void injectIncomingTx(String txHex) {
     _transactionController.add(txHex);
  }
  
  void injectDownloadProgress(double progress) {
     downloadProgressNotifier.value = progress;
  }


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
      
      debugPrint('Started BLE advertising (Chunked Mode). Size: \${txBytes.length} bytes.');
      
      // Start broadcasting chunks in a loop
      // This allows the receiver to jump in at any point and collect all fragments
      _startChunkLoop(MeshProtocol.fragment(Uint8List.fromList(txBytes)));
      
    } catch (e) {
      _isAdvertising = false;
      rethrow;
    }
  }

  void _startChunkLoop(List<Uint8List> chunks) {
    if (chunks.isEmpty) return;
    
    int index = 0;
    _advertisingLoopTimer?.cancel();
    
    // 200ms is a conservative balance between speed and reliability for BLE notifications
    _advertisingLoopTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
       if (!_isAdvertising) {
         timer.cancel();
         uploadProgressNotifier.value = 0.0;
         return;
       }

       
       try {
         // Update the characteristic value with the current chunk
         // Note: We use the same UUID. The value changes dynamically.
         await FlutterBlePeripheral().write(
           characteristicUuid: _txCharacteristicUuid,
           data: chunks[index],
         );
         
         // Update UI Progress
         // We essentially loop forever, so progress is cyclic: 0..1..0..1
         uploadProgressNotifier.value = (index + 1) / chunks.length;
         
         // Move to next chunk (Looping)
         index = (index + 1) % chunks.length;
       } catch (e) {
         debugPrint('Mesh: Error writing chunk: \$e');
       }
    });
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    _advertisingLoopTimer?.cancel();
    _advertisingLoopTimer = null;
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
                     // Subscribe to Notifications (Accumulator Model)
                     await txChar.setNotifyValue(true);
                     
                     // Buffer to store chunks: <Index, Data>
                     Map<int, Uint8List> receivedChunks = {};
                     
                     // Stream processed locally to handle async breaks
                     bool isReassemblyComplete = false;
                     
                     // Listen to the stream
                     // We use a completer or just loop within the stream? 
                     // Since we need to disconnect after success, we might need a complex flow.
                     // For simplicity, we listen and trigger the disconnect logic inside.
                     
                     final subscription = txChar.lastValueStream.listen((value) async {
                        if (value.isEmpty) return;
                        
                        try {
                          final chunk = Uint8List.fromList(value);
                          final header = MeshProtocol.parseHeader(chunk);
                          
                          // Store chunk
                          receivedChunks[header.index] = chunk; // Store full chunk (MeshProtocol handles stripping)
                          
                          // Update UI Progress
                          downloadProgressNotifier.value = receivedChunks.length / header.totalChunks;
                          
                          debugPrint('Mesh: Rx Chunk \${header.index + 1}/\${header.totalChunks} (Progress: \${(downloadProgressNotifier.value * 100).toStringAsFixed(1)}%)');
                          
                          // Attempt Reassembly
                          final fullPayload = MeshProtocol.reassemble(receivedChunks);
                          
                          if (fullPayload != null) {
                             String txHex = hex.encode(fullPayload);
                             debugPrint('Mesh: Full Payload Reassembled! (\${fullPayload.length} bytes)');
                             
                             if (isValidTxHex(txHex)) {
                               _transactionController.add(txHex);
                               debugPrint('Mesh: Valid Tx Relayed. Closing connection.');
                               isReassemblyComplete = true;
                               // Reset progress
                               downloadProgressNotifier.value = 1.0; // Ensure 100% shown
                             } else {
                               debugPrint('Mesh: Reassembled packet invalid.');
                             }
                          }
                        } catch (e) {
                           debugPrint('Mesh: error parsing chunk: \$e');
                        }
                     });
                     
                     // Wait for completion or timeout
                     // We give it reasonable time to loop through chunks (e.g. 5KB @ 200ms/chunk ~ 50 chunks ~ 10s)
                     int waitMs = 0;
                     while (!isReassemblyComplete && waitMs < 30000) {
                        await Future.delayed(const Duration(milliseconds: 500));
                        waitMs += 500;
                     }
                     
                     await subscription.cancel();
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
      }); // Close listen
    } catch (e) {
      debugPrint("Error connecting to mesh peer: \$e");
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
