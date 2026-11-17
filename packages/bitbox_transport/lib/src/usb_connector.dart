import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'platform.dart';

import 'package:rust_bindings/bitbox.dart' as api;

/// Transfers USB frames between the native transport and Rust queues.
class UsbConnector {
  static final UsbConnector _instance = UsbConnector._internal();
  factory UsbConnector() => _instance;
  UsbConnector._internal();

  Timer? _pollTimer;
  bool _isPolling = false;
  int _sessionId = 0;

  void start({String? deviceSerial}) {
    if (_pollTimer != null) return;
    final sessionId = ++_sessionId;
    final serialNumber = deviceSerial ?? '';

    // The device requires keepalives during user confirmation. Transfer
    // frames promptly; the protocol layer already controls retry timing.
    _pollTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      unawaited(_pollForData(sessionId, serialNumber));
    });
  }

  void stop() {
    _sessionId++;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollForData(int sessionId, String serialNumber) async {
    if (_isPolling || sessionId != _sessionId) return;
    _isPolling = true;
    try {
      // A request can span multiple frames. Send all of them before waiting
      // for its response, without running concurrent native reads/writes.
      while (sessionId == _sessionId) {
        final data = api.getUsbWriteDataWrapper(serialNumber: serialNumber);
        if (data == null || data.isEmpty) break;
        await BitBoxFlutterPlatform.sendData(Uint8List.fromList(data));
      }
      if (sessionId != _sessionId) return;

      final data = await BitBoxFlutterPlatform.receiveData();
      if (sessionId != _sessionId || data.isEmpty) return;
      api.setUsbReadDataWrapper(serialNumber: serialNumber, data: data);
    } on Exception catch (error, stackTrace) {
      if (sessionId != _sessionId) return;
      developer.log(
        'USB transfer failed',
        name: 'bitbox_transport',
        error: error,
        stackTrace: stackTrace,
      );
      stop();
    } finally {
      _isPolling = false;
    }
  }

  Future<void> sendData(Uint8List data) async {
    await BitBoxFlutterPlatform.sendData(data);
  }
}
