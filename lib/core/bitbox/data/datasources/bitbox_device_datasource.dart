import 'dart:async';
import 'dart:io' show Platform;

import 'package:bb_mobile/core/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bitbox_transport/bitbox_transport.dart';
import 'package:bull_sdk/bitbox.dart' as bitbox;
import 'package:universal_ble/universal_ble.dart';

class BitBoxDeviceDatasource {
  final BleConnector _bleConnector = BleConnector();
  int _usbScanSessionId = 0;
  BitBoxDeviceModel? _connectedDevice;

  BitBoxConnectionType get _platformTransport =>
      Platform.isAndroid ? BitBoxConnectionType.usb : BitBoxConnectionType.ble;

  Future<List<BitBoxDeviceModel>> scanDevices() async {
    try {
      await _bleConnector.stopScan();
      final usbScanSessionId = ++_usbScanSessionId;

      switch (_platformTransport) {
        case BitBoxConnectionType.usb:
          return await _scanUsbDevices(usbScanSessionId);
        case BitBoxConnectionType.ble:
          return await _scanBleDevices();
      }
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<List<BitBoxDeviceModel>> _scanUsbDevices(
    int usbScanSessionId, {
    Duration timeout = const Duration(seconds: 20),
    Duration interval = const Duration(milliseconds: 750),
  }) async {
    final deadline = DateTime.now().add(timeout);
    Exception? lastScanError;
    var scanSucceeded = false;

    while (DateTime.now().isBefore(deadline)) {
      if (usbScanSessionId != _usbScanSessionId) {
        throw const OperationCancelledBitBoxFailure();
      }

      var devices = <BitBox02Device>[];
      try {
        devices = await BitBoxApi.scanDevices();
        scanSucceeded = true;
      } on Exception catch (e) {
        lastScanError = e;
        log.fine('BitBox USB scan attempt failed', error: e);
      }

      if (usbScanSessionId != _usbScanSessionId) {
        throw const OperationCancelledBitBoxFailure();
      }
      if (devices.isNotEmpty) {
        final deviceModels = devices.map((device) {
          return BitBoxDeviceModel.fromBitBoxDevice(
            deviceName: device.deviceName,
            serialNumber: device.serialNumber,
            product: device.product,
            connectionType: BitBoxConnectionType.usb,
          );
        }).toList();

        return _ensureSingleDevice(deviceModels);
      }

      await Future<void>.delayed(interval);
    }

    if (!scanSucceeded && lastScanError != null) {
      throw _mapOperationError(lastScanError);
    }

    throw const NoDevicesFoundBitBoxFailure();
  }

  Future<List<BitBoxDeviceModel>> _scanBleDevices() async {
    await _ensureBleTransportReady();

    final List<BitBox02BleDevice> devices;
    try {
      devices = await _scanBleDevicesForDuration();
    } on UniversalBleException catch (e) {
      if (_isBlePermissionError(e)) {
        throw const PermissionDeniedBitBoxFailure();
      }
      if (_isBleUnavailableError(e)) {
        throw const BluetoothUnavailableBitBoxFailure();
      }
      rethrow;
    }
    final deviceModels = devices.map((device) {
      return BitBoxDeviceModel.fromBitBoxDevice(
        deviceName: device.name ?? 'BitBox02 Nova',
        // BLE uses the platform device id as the transport queue key.
        serialNumber: device.deviceId,
        product: 'BitBox02 Nova',
        connectionType: BitBoxConnectionType.ble,
      );
    }).toList();

    return _ensureSingleDevice(deviceModels);
  }

  Future<List<BitBox02BleDevice>> _scanBleDevicesForDuration({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    return await _bleConnector.scanDevices(
      timeout: timeout,
      settleDuration: const Duration(seconds: 2),
    );
  }

  Future<void> _ensureBleTransportReady() async {
    try {
      final bleState = await UniversalBle.getBluetoothAvailabilityState();
      if (bleState == AvailabilityState.unauthorized) {
        throw const PermissionDeniedBitBoxFailure();
      }
      if (bleState == AvailabilityState.unsupported ||
          bleState == AvailabilityState.poweredOff) {
        throw const BluetoothUnavailableBitBoxFailure();
      }
      if (bleState != AvailabilityState.poweredOn) {
        await _waitForBleTransportReady();
      }
    } on UniversalBleException catch (e) {
      if (_isBlePermissionError(e)) {
        throw const PermissionDeniedBitBoxFailure();
      }
      if (_isBleUnavailableError(e)) {
        throw const BluetoothUnavailableBitBoxFailure();
      }
      rethrow;
    }
  }

  Future<void> _waitForBleTransportReady({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final bleState = await UniversalBle.availabilityStream
        .where(
          (state) =>
              state != AvailabilityState.unknown &&
              state != AvailabilityState.resetting,
        )
        .first
        .timeout(
          timeout,
          onTimeout: () {
            log.warning('BitBox BLE availability wait timed out');
            return AvailabilityState.unknown;
          },
        );

    if (bleState == AvailabilityState.poweredOn) return;
    if (bleState == AvailabilityState.unauthorized) {
      throw const PermissionDeniedBitBoxFailure();
    }
    throw const BluetoothUnavailableBitBoxFailure();
  }

  bool _isBlePermissionError(UniversalBleException error) {
    return switch (_bleErrorCode(error)) {
      UniversalBleErrorCode.bluetoothNotAllowed ||
      UniversalBleErrorCode.bluetoothUnauthorized => true,
      _ => false,
    };
  }

  bool _isBleUnavailableError(UniversalBleException error) {
    return switch (_bleErrorCode(error)) {
      UniversalBleErrorCode.notSupported ||
      UniversalBleErrorCode.bluetoothNotAvailable ||
      UniversalBleErrorCode.bluetoothNotEnabled => true,
      _ => false,
    };
  }

  bool _isBleConnectionError(UniversalBleException error) {
    return switch (_bleErrorCode(error)) {
      UniversalBleErrorCode.deviceDisconnected ||
      UniversalBleErrorCode.connectionFailed ||
      UniversalBleErrorCode.connectionRejected ||
      UniversalBleErrorCode.connectionLimitExceeded ||
      UniversalBleErrorCode.connectionAlreadyExists ||
      UniversalBleErrorCode.connectionTerminated ||
      UniversalBleErrorCode.connectionInProgress ||
      UniversalBleErrorCode.deviceNotFound => true,
      _ => false,
    };
  }

  UniversalBleErrorCode _bleErrorCode(UniversalBleException error) {
    final details = error.details;
    return details is UniversalBleException ? details.code : error.code;
  }

  List<BitBoxDeviceModel> _ensureSingleDevice(List<BitBoxDeviceModel> devices) {
    if (devices.isEmpty) {
      throw const NoDevicesFoundBitBoxFailure();
    }
    if (devices.length > 1) {
      throw const MultipleDevicesFoundBitBoxFailure();
    }

    return devices;
  }

  Future<BitBoxDeviceModel> connectDevice(BitBoxDeviceModel device) async {
    try {
      await _disconnectCurrentConnection();

      switch (device.connectionType) {
        case BitBoxConnectionType.usb:
          return await _connectUsbDevice(device);
        case BitBoxConnectionType.ble:
          return await _connectBleDevice(device);
      }
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<BitBoxDeviceModel> _connectUsbDevice(BitBoxDeviceModel device) async {
    if (_platformTransport != BitBoxConnectionType.usb) {
      throw const ConnectionTypeNotInitializedBitBoxFailure();
    }

    final hasPermission = await BitBoxApi.requestPermission(device.deviceName);
    if (!hasPermission) {
      throw const PermissionDeniedBitBoxFailure();
    }

    final opened = await BitBoxApi.openDevice(
      device.deviceName,
      device.serialNumber,
    );
    if (!opened) {
      throw const ConnectionFailedBitBoxFailure();
    }

    _connectedDevice = device;
    return device;
  }

  Future<BitBoxDeviceModel> _connectBleDevice(BitBoxDeviceModel device) async {
    if (_platformTransport != BitBoxConnectionType.ble) {
      throw const ConnectionTypeNotInitializedBitBoxFailure();
    }

    await _ensureBleTransportReady();

    final bool connected;
    try {
      connected = await _bleConnector.connect(
        deviceId: device.serialNumber,
        serialNumber: device.serialNumber,
      );
    } on TimeoutException {
      throw const OperationTimeoutBitBoxFailure();
    } on UniversalBleException catch (e) {
      if (_isBlePermissionError(e)) {
        throw const PermissionDeniedBitBoxFailure();
      }
      if (_isBleUnavailableError(e)) {
        throw const BluetoothUnavailableBitBoxFailure();
      }
      if (_bleErrorCode(e) == UniversalBleErrorCode.connectionTimeout) {
        throw const OperationTimeoutBitBoxFailure();
      }
      if (e is ConnectionException || _isBleConnectionError(e)) {
        throw const ConnectionFailedBitBoxFailure();
      }
      rethrow;
    }
    if (!connected) {
      throw const ConnectionFailedBitBoxFailure();
    }

    _connectedDevice = device;
    return device;
  }

  Future<String> unlockDevice(BitBoxDeviceModel device) async {
    try {
      // Hardware operations use the Rust API directly; BitBoxApi owns Android
      // USB transport setup.
      final pairingCode = await bitbox.startPairing(
        serialNumber: device.serialNumber,
      );

      return pairingCode ?? '';
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<String> pairDevice(BitBoxDeviceModel device) async {
    try {
      final confirmed = await bitbox.confirmPairing(
        serialNumber: device.serialNumber,
      );

      if (!confirmed) {
        throw const OperationCancelledBitBoxFailure();
      }

      return await getMasterFingerprint(device);
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<String> getXpub(
    BitBoxDeviceModel device, {
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      final xpubType = isTestnet ? 'tpub' : 'xpub';

      final xpub = await bitbox.getBtcXpub(
        serialNumber: device.serialNumber,
        keypath: derivationPath,
        xpubType: xpubType,
      );
      return xpub;
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<String> getMasterFingerprint(BitBoxDeviceModel device) async {
    try {
      return await bitbox.getRootFingerprint(serialNumber: device.serialNumber);
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<String> signPsbt(
    BitBoxDeviceModel device, {
    required String psbt,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      final signedPsbt = await bitbox.signPsbt(
        serialNumber: device.serialNumber,
        psbtStr: psbt,
        testnet: isTestnet,
      );
      return signedPsbt;
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  Future<bool> verifyAddress(
    BitBoxDeviceModel device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
    required bool isTestnet,
  }) async {
    try {
      final String bitboxScriptType = scriptType == ScriptType.bip49
          ? 'p2wpkhp2sh'
          : 'p2wpkh';

      final verifiedAddress = await bitbox.verifyAddress(
        serialNumber: device.serialNumber,
        keypath: derivationPath,
        testnet: isTestnet,
        scriptType: bitboxScriptType,
      );
      return verifiedAddress == address;
    } catch (e) {
      throw _mapOperationError(e);
    }
  }

  BitBoxFailure _mapOperationError(Object error) {
    if (error is BitBoxFailure) return error;

    return _interpretOperationError(error.toString()) ??
        BitBoxUnexpectedFailure(error.toString());
  }

  BitBoxFailure? _interpretOperationError(String raw) {
    final normalized = raw.toLowerCase();

    if (normalized.contains('permission denied')) {
      return const PermissionDeniedBitBoxFailure();
    }
    if (normalized.contains('no devices found')) {
      return const NoDevicesFoundBitBoxFailure();
    }
    if (normalized.contains('device not found')) {
      return const DeviceNotFoundBitBoxFailure();
    }
    if (normalized.contains('device not paired') ||
        normalized.contains('not paired')) {
      return const DeviceNotPairedBitBoxFailure();
    }
    if (normalized.contains('handshake')) {
      return const HandshakeFailedBitBoxFailure();
    }
    if (normalized.contains('timeout')) {
      return const OperationTimeoutBitBoxFailure();
    }
    if (normalized.contains('connection failed')) {
      return const ConnectionFailedBitBoxFailure();
    }
    if (normalized.contains('invalid response')) {
      return const InvalidResponseBitBoxFailure();
    }
    if (normalized.contains('operation cancelled') ||
        normalized.contains('operation canceled')) {
      return const OperationCancelledBitBoxFailure();
    }
    return null;
  }

  Future<void> disconnectConnection(BitBoxDeviceModel device) async {
    await _disconnectCurrentConnection(device);
  }

  Future<void> _disconnectCurrentConnection([
    BitBoxDeviceModel? fallbackDevice,
  ]) async {
    final device = _connectedDevice ?? fallbackDevice;
    if (device == null) return;

    try {
      await _disconnectDevice(device.serialNumber, device.connectionType);
    } catch (e) {
      log.warning('Error disconnecting BitBox device', error: e);
    } finally {
      if (_connectedDevice?.serialNumber == device.serialNumber) {
        _connectedDevice = null;
      }
    }
  }

  Future<void> _disconnectDevice(
    String serialNumber,
    BitBoxConnectionType connectionType,
  ) async {
    switch (connectionType) {
      case BitBoxConnectionType.usb:
        await BitBoxApi.closeDevice(serialNumber);
        break;
      case BitBoxConnectionType.ble:
        await _bleConnector.disconnect();
        break;
    }
  }

  Future<void> dispose() async {
    _usbScanSessionId++;
    await _bleConnector.stopScan();
    if (_connectedDevice != null) {
      await _disconnectCurrentConnection();
    } else if (_platformTransport == BitBoxConnectionType.ble) {
      await _bleConnector.disconnect();
    }
  }
}
