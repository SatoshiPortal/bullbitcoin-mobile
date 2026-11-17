import 'dart:async';
import 'dart:typed_data';

import 'package:bull_sdk/bitbox.dart' as api;
import 'package:universal_ble/universal_ble.dart';

const _bleConnectionTimeout = Duration(seconds: 30);
const _blePollInterval = Duration(milliseconds: 20);
const _bleMaxWriteFrames = 5;

/// BitBox02 Nova BLE Service and Characteristic UUIDs
const bleServiceUuid = 'E1511A45-F3DB-44C0-82B8-6C880790D1F1';
const bleRxUuid = '799D485C-D354-4ED0-B577-F8EE79EC275A';
const bleTxUuid = '419572A5-9F53-4EB1-8DB7-61BCAB928867';
const bleProductUuid = '9D1C9A77-8B03-4E49-8053-3955CDA7DA93';

/// Discovered BitBox02 Nova device via BLE
class BitBox02BleDevice {
  final String deviceId;
  final String? name;

  const BitBox02BleDevice({required this.deviceId, this.name});

  @override
  String toString() => 'BitBox02BleDevice(id: $deviceId, name: $name)';
}

/// BLE connector for BitBox02 Nova communication.
///
/// Bridges BLE characteristic reads/writes to Rust's in-memory queues,
/// using the same protocol as USB (64-byte U2F HID frames).
class BleConnector {
  static final BleConnector _instance = BleConnector._internal();
  factory BleConnector() => _instance;
  BleConnector._internal();

  String? _connectedDeviceId;
  String? _serialNumber;
  final List<BitBox02BleDevice> _scanDevices = <BitBox02BleDevice>[];
  StreamSubscription<BleDevice>? _scanSubscription;
  Timer? _scanSettleTimer;
  Completer<List<BitBox02BleDevice>>? _scanCompleter;
  bool _scanStarted = false;
  StreamSubscription<Uint8List>? _valueSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _pollTimer;
  bool _isPolling = false;
  int _maxWriteFrames = 1;
  int _sessionId = 0;

  /// Scan for BitBox02 Nova devices advertising the BLE service.
  Future<List<BitBox02BleDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 5),
    Duration? settleDuration,
  }) async {
    await stopScan();

    final completer = Completer<List<BitBox02BleDevice>>();
    _scanDevices.clear();
    _scanCompleter = completer;

    _scanSubscription = UniversalBle.scanStream.listen(
      (device) {
        if (_scanCompleter != completer || completer.isCompleted) return;

        final alreadyFound = _scanDevices.any(
          (d) => d.deviceId == device.deviceId,
        );
        if (alreadyFound) return;

        _scanDevices.add(
          BitBox02BleDevice(deviceId: device.deviceId, name: device.name),
        );

        if (settleDuration != null) {
          _scanSettleTimer ??= Timer(settleDuration, () {
            if (_scanCompleter != completer) return;
            if (!completer.isCompleted) {
              completer.complete(List<BitBox02BleDevice>.from(_scanDevices));
            }
          });
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      _scanStarted = true;
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: [bleServiceUuid]),
      );

      return await completer.future.timeout(
        timeout,
        onTimeout: () => List<BitBox02BleDevice>.from(_scanDevices),
      );
    } finally {
      if (_scanCompleter == completer) {
        await stopScan();
      }
    }
  }

  Future<void> stopScan() async {
    final completer = _scanCompleter;
    final subscription = _scanSubscription;
    final devices = List<BitBox02BleDevice>.from(_scanDevices);
    final shouldStopScan = _scanStarted;

    if (completer == null && subscription == null && !shouldStopScan) {
      return;
    }

    _scanCompleter = null;
    _scanSubscription = null;
    _scanSettleTimer?.cancel();
    _scanSettleTimer = null;
    _scanStarted = false;
    _scanDevices.clear();

    try {
      await subscription?.cancel();
    } catch (_) {}

    if (shouldStopScan) {
      try {
        await UniversalBle.stopScan();
      } catch (_) {}
    }

    if (completer != null && !completer.isCompleted) {
      completer.complete(devices);
    }
  }

  /// Connect to a BitBox02 Nova and start shuttling data to Rust queues.
  ///
  /// Returns `false` when setup is interrupted by another connection attempt.
  /// Throws [TimeoutException] or [UniversalBleException] for BLE failures so
  /// callers can preserve platform-specific error details. Unexpected setup
  /// errors are rethrown with their original stack trace.
  Future<bool> connect({
    required String deviceId,
    required String serialNumber,
    Duration timeout = _bleConnectionTimeout,
  }) async {
    await disconnect();
    final sessionId = _sessionId;
    _connectedDeviceId = deviceId;
    _serialNumber = serialNumber;

    StreamSubscription<Uint8List>? valueSubscription;
    StreamSubscription<bool>? connectionSubscription;
    try {
      await UniversalBle.connect(deviceId, timeout: timeout);
      if (!_isCurrentSession(sessionId, deviceId, serialNumber)) {
        await _disconnectStaleDevice(deviceId, serialNumber);
        return false;
      }

      await UniversalBle.discoverServices(deviceId);
      if (!_isCurrentSession(sessionId, deviceId, serialNumber)) {
        await _disconnectStaleDevice(deviceId, serialNumber);
        return false;
      }
      _maxWriteFrames = await _resolveMaxWriteFrames(deviceId);

      connectionSubscription = UniversalBle.connectionStream(deviceId).listen(
        (isConnected) {
          if (isConnected ||
              !_isCurrentSession(sessionId, deviceId, serialNumber)) {
            return;
          }

          unawaited(_cleanupCurrentConnection(disconnectBle: false));
        },
        onError: (_) {
          if (!_isCurrentSession(sessionId, deviceId, serialNumber)) return;
          unawaited(_cleanupCurrentConnection(disconnectBle: false));
        },
      );

      valueSubscription =
          UniversalBle.characteristicValueStream(deviceId, bleTxUuid).listen(
            (value) {
              if (!_isCurrentSession(sessionId, deviceId, serialNumber)) return;

              try {
                api.setUsbReadDataWrapper(
                  serialNumber: serialNumber,
                  data: value.toList(),
                );
              } catch (_) {
                if (!_isCurrentSession(sessionId, deviceId, serialNumber)) {
                  return;
                }
                unawaited(_cleanupCurrentConnection(disconnectBle: true));
              }
            },
            onError: (_) {
              if (!_isCurrentSession(sessionId, deviceId, serialNumber)) return;
              unawaited(_cleanupCurrentConnection(disconnectBle: false));
            },
          );

      await UniversalBle.subscribeIndications(
        deviceId,
        bleServiceUuid,
        bleTxUuid,
      );
      if (!_isCurrentSession(sessionId, deviceId, serialNumber)) {
        await valueSubscription.cancel();
        await connectionSubscription.cancel();
        await _disconnectStaleDevice(deviceId, serialNumber);
        return false;
      }

      _valueSubscription = valueSubscription;
      valueSubscription = null;
      _connectionSubscription = connectionSubscription;
      connectionSubscription = null;
      _startPolling(sessionId, deviceId, serialNumber);

      return true;
    } catch (e, stackTrace) {
      await valueSubscription?.cancel();
      await connectionSubscription?.cancel();
      if (_isCurrentSession(sessionId, deviceId, serialNumber)) {
        await disconnect();
      } else {
        await _disconnectStaleDevice(deviceId, serialNumber);
      }
      if (e is TimeoutException || e is UniversalBleException) rethrow;
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  /// Read the PRODUCT characteristic to get device info JSON.
  Future<String?> readProductInfo() async {
    final deviceId = _connectedDeviceId;
    if (deviceId == null) return null;

    try {
      final data = await UniversalBle.read(
        deviceId,
        bleServiceUuid,
        bleProductUuid,
      );
      return String.fromCharCodes(data);
    } catch (e) {
      return null;
    }
  }

  void _startPolling(int sessionId, String deviceId, String serialNumber) {
    _pollTimer = Timer.periodic(_blePollInterval, (_) {
      unawaited(_pollForData(sessionId, deviceId, serialNumber));
    });
  }

  Future<void> _pollForData(
    int sessionId,
    String deviceId,
    String serialNumber,
  ) async {
    if (_isPolling || !_isCurrentSession(sessionId, deviceId, serialNumber)) {
      return;
    }

    _isPolling = true;
    try {
      final writeData = _getNextWriteData(serialNumber);

      if (writeData == null || writeData.isEmpty) return;

      await UniversalBle.write(deviceId, bleServiceUuid, bleRxUuid, writeData);
    } catch (e) {
      if (_isCurrentSession(sessionId, deviceId, serialNumber)) {
        await _cleanupCurrentConnection(disconnectBle: true);
      }
    } finally {
      _isPolling = false;
    }
  }

  Uint8List? _getNextWriteData(String serialNumber) {
    final frames = <List<int>>[];

    for (var i = 0; i < _maxWriteFrames; i++) {
      final writeData = api.getUsbWriteDataWrapper(serialNumber: serialNumber);
      if (writeData == null || writeData.isEmpty) break;
      frames.add(writeData);
    }

    if (frames.isEmpty) return null;

    final dataLength = frames.fold<int>(
      0,
      (length, frame) => length + frame.length,
    );
    final data = Uint8List(dataLength);
    var offset = 0;
    for (final frame in frames) {
      data.setRange(offset, offset + frame.length, frame);
      offset += frame.length;
    }
    return data;
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    await stopScan();
    await _cleanupCurrentConnection(disconnectBle: true);
  }

  Future<void> _cleanupCurrentConnection({required bool disconnectBle}) async {
    final deviceId = _connectedDeviceId;
    final serialNumber = _serialNumber;

    _sessionId++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _connectedDeviceId = null;
    _serialNumber = null;
    _maxWriteFrames = 1;

    try {
      await _valueSubscription?.cancel();
    } catch (_) {}
    _valueSubscription = null;

    try {
      await _connectionSubscription?.cancel();
    } catch (_) {}
    _connectionSubscription = null;

    if (deviceId != null) {
      await _closeConnection(
        deviceId,
        serialNumber,
        disconnectBle: disconnectBle,
      );
    }
  }

  Future<void> _disconnectStaleDevice(
    String deviceId,
    String? serialNumber,
  ) async {
    if (_connectedDeviceId == deviceId) return;
    await _closeConnection(deviceId, serialNumber, disconnectBle: true);
  }

  Future<void> _closeConnection(
    String deviceId,
    String? serialNumber, {
    required bool disconnectBle,
  }) async {
    if (serialNumber != null) {
      // Close only the transport queues. The paired Rust BitBox remains
      // registered so reconnects do not require another Noise pairing code.
      try {
        await api.closeUsbChannel(serialNumber: serialNumber);
      } catch (_) {}
    }

    if (!disconnectBle) return;

    try {
      await UniversalBle.disconnect(deviceId);
    } catch (_) {}
  }

  Future<int> _resolveMaxWriteFrames(String deviceId) async {
    try {
      final mtu = await UniversalBle.requestMtu(deviceId, 512);
      final maxWriteLength = mtu > 3 ? mtu - 3 : 0;
      final frames = maxWriteLength ~/ 64;
      return frames.clamp(1, _bleMaxWriteFrames);
    } catch (_) {
      return 1;
    }
  }

  bool _isCurrentSession(int sessionId, String deviceId, String serialNumber) {
    return sessionId == _sessionId &&
        _connectedDeviceId == deviceId &&
        _serialNumber == serialNumber;
  }

  bool get isConnected => _connectedDeviceId != null && _pollTimer != null;
}
