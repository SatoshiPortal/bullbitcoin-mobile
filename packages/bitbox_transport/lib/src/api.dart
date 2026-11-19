import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:rust_bindings/bitbox.dart' as api;
import 'package:rust_bindings/rust_bindings.dart';

import 'platform.dart';
import 'usb_connector.dart';

class BitBoxApi {
  static bool _initialized = false;
  static Future<void>? _usbWorker;
  static SendPort? _stopUsbWorker;

  /// Marks the transport ready. The host app must call `BullSdk.init()` first:
  /// BitBox shares that native library, and a second init throws.
  static Future<void> initialize() async {
    _initialized = true;
  }

  static Future<List<BitBox02Device>> scanDevices() async {
    _ensureInitialized();
    return await BitBoxFlutterPlatform.scanDevices();
  }

  static Future<bool> requestPermission(String deviceName) async {
    _ensureInitialized();
    return await BitBoxFlutterPlatform.requestPermission(deviceName);
  }

  static Future<bool> openDevice(String deviceName, String serialNumber) async {
    _ensureInitialized();

    final opened = await BitBoxFlutterPlatform.openDevice(deviceName);
    if (!opened) {
      return false;
    }

    final ready = ReceivePort();
    final readyPort = ready.sendPort;
    final rootToken = ServicesBinding.rootIsolateToken!;
    final worker = Isolate.run(
      () => _runUsbWorker(rootToken, serialNumber, readyPort),
    );
    _usbWorker = worker;
    try {
      _stopUsbWorker = await Future.any<SendPort>([
        ready.first.then((message) => message as SendPort),
        worker.then(
          (_) => throw StateError('USB worker exited before startup'),
        ),
      ]);
    } catch (_) {
      _usbWorker = null;
      rethrow;
    } finally {
      ready.close();
    }

    return true;
  }

  static Future<String?> startPairing(String serialNumber) async {
    _ensureInitialized();
    return await api.startPairing(serialNumber: serialNumber);
  }

  static Future<bool> confirmPairing(String serialNumber) async {
    _ensureInitialized();
    return await api.confirmPairing(serialNumber: serialNumber);
  }

  static Future<String> getRootFingerprint(String serialNumber) async {
    _ensureInitialized();
    return await api.getRootFingerprint(serialNumber: serialNumber);
  }

  /// Fetches an account extended public key from the device.
  ///
  /// [xpubType] is required on purpose: it used to default to `xpub`, so a
  /// BIP84 or BIP49 account silently came back with a legacy prefix and any
  /// consumer reading the prefix built a watch-only wallet on the wrong
  /// script type. Pass [BitBoxKeypath.xpubTypeFor] unless you deliberately
  /// want a different encoding.
  static Future<String> getBtcXpub({
    required String serialNumber,
    required String keypath,
    required String xpubType,
  }) async {
    _ensureInitialized();
    return await api.getBtcXpub(
      serialNumber: serialNumber,
      keypath: keypath,
      xpubType: xpubType,
    );
  }

  /// Asks the device to display an address for confirmation.
  ///
  /// [testnet] is required on purpose: defaulting to mainnet meant a caller
  /// that forgot the flag had the device confirm a mainnet address while the
  /// app believed it was on testnet.
  static Future<String> verifyAddress({
    required String serialNumber,
    required String keypath,
    required bool testnet,
    String scriptType = 'p2wpkh',
  }) async {
    _ensureInitialized();
    return await api.verifyAddress(
      serialNumber: serialNumber,
      keypath: keypath,
      testnet: testnet,
      scriptType: scriptType,
    );
  }

  /// Signs a PSBT on the device.
  ///
  /// [testnet] is required on purpose: it selects the network the device
  /// signs under, and defaulting it to mainnet made a cross-network signature
  /// the silent outcome of forgetting an argument.
  static Future<String> signPsbt({
    required String serialNumber,
    required String psbt,
    required bool testnet,
  }) async {
    _ensureInitialized();
    return await api.signPsbt(
      serialNumber: serialNumber,
      psbtStr: psbt,
      testnet: testnet,
    );
  }

  static Future<void> closeDevice(String serialNumber) async {
    _ensureInitialized();

    _stopUsbWorker?.send(null);
    await _usbWorker;
    _stopUsbWorker = null;
    _usbWorker = null;

    // Preserve the paired session for subsequent actions on this device.
    await api.closeUsbChannel(serialNumber: serialNumber);

    await BitBoxFlutterPlatform.closeDevice();
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('BitBoxApi not initialized. Call initialize() first.');
    }
  }
}

// USB keepalives must continue while Flutter is busy rendering or running app
// code. The Rust queues are shared; only the frame pump runs in this isolate.
Future<void> _runUsbWorker(
  RootIsolateToken rootToken,
  String serialNumber,
  SendPort ready,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
  await BullSdk.init();
  final stop = ReceivePort();
  final connector = UsbConnector();
  try {
    connector.start(deviceSerial: serialNumber);
    ready.send(stop.sendPort);
    await stop.first;
  } finally {
    connector.stop();
    stop.close();
  }
}
