import 'dart:io' show Platform;
import 'package:bb_mobile/core_deprecated/bitbox/data/models/bitbox_device_model.dart';
import 'package:bb_mobile/core_deprecated/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core_deprecated/bitbox/domain/errors/bitbox_errors.dart';
import 'package:bb_mobile/core_deprecated/wallet/domain/entities/wallet.dart';
import 'package:bitbox_flutter/bitbox_flutter.dart';

class BitBoxDeviceDatasource {
  final Set<String> _connectedDevices = <String>{};
  BitBoxDeviceModel? _cachedDevice;

  Future<List<BitBoxDeviceModel>> scanDevices() async {
    try {
      if (!Platform.isAndroid) {
        throw const BitBoxError.operationFailed(message: 'BitBox is only supported on Android');
      }
      
      final devices = await BitBoxFlutterApi.scanDevices();
      
      return devices.map((device) => BitBoxDeviceModel.fromBitBoxDevice(
        deviceName: device.deviceName,
        serialNumber: device.serialNumber,
        product: device.product,
        connectionType: BitBoxConnectionType.usb,
      )).toList();
    } catch (e) {
      if (e is BitBoxError) rethrow;
      throw BitBoxError.operationFailed(message: e.toString());
    }
  }

  Future<BitBoxDeviceModel> connectDevice(BitBoxDeviceModel device) async {
    try {
      if (!Platform.isAndroid) {
        throw const BitBoxError.operationFailed(message: 'BitBox is only supported on Android');
      }
      
      final hasPermission = await BitBoxFlutterApi.requestPermission(device.deviceName);
      if (!hasPermission) {
        throw const BitBoxError.permissionDenied();
      }
      
      final opened = await BitBoxFlutterApi.openDevice(
        device.deviceName, 
        device.serialNumber,
      );
      if (!opened) {
        throw const BitBoxError.operationFailed(message: 'Failed to open device');
      }
      
      _connectedDevices.add(device.serialNumber);
      _cachedDevice = device;
      return device;
    } catch (e) {
      if (e is BitBoxError) rethrow;
      throw BitBoxError.operationFailed(message: e.toString());
    }
  }

  Future<String> unlockDevice(BitBoxDeviceModel device) async {
    try {
      final pairingCode = await BitBoxFlutterApi.startPairing(device.serialNumber);
      
      if (pairingCode != null && pairingCode.isNotEmpty) {
        return pairingCode;
      } else {
        return '';
      }
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
    }
  }

  Future<String> pairDevice(BitBoxDeviceModel device) async {
    try {
      final confirmed = await BitBoxFlutterApi.confirmPairing(device.serialNumber);
      
      if (!confirmed) {
        throw const BitBoxError.operationFailed(message: 'Pairing confirmation failed');
      }
      
      return await BitBoxFlutterApi.getRootFingerprint(device.serialNumber);
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
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
      
      final xpub = await BitBoxFlutterApi.getBtcXpub(
        serialNumber: device.serialNumber,
        keypath: derivationPath,
        xpubType: xpubType,
      );
      return xpub;
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
    }
  }

  Future<String> getMasterFingerprint(BitBoxDeviceModel device) async {
    try {
      return await BitBoxFlutterApi.getRootFingerprint(device.serialNumber);
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
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
      final signedPsbt = await BitBoxFlutterApi.signPsbt(
        serialNumber: device.serialNumber,
        psbt: psbt,
        testnet: isTestnet,
      );
      return signedPsbt;
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
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
      final String bitboxScriptType = scriptType == ScriptType.bip49 ? 'p2wpkhp2sh' : 'p2wpkh';
      
      final verifiedAddress = await BitBoxFlutterApi.verifyAddress(
        serialNumber: device.serialNumber,
        keypath: derivationPath,
        testnet: isTestnet,
        scriptType: bitboxScriptType,
      );
      return verifiedAddress == address;
    } catch (e) {
      throw BitBoxError.operationFailed(message: e.toString());
    }
  }

  Future<void> disconnectConnection(BitBoxDeviceModel device) async {
    try {
      await BitBoxFlutterApi.closeDevice(device.serialNumber);
      
      _connectedDevices.remove(device.serialNumber);
      if (_cachedDevice?.serialNumber == device.serialNumber) {
        _cachedDevice = null;
      }
    } catch (e) {
      _connectedDevices.remove(device.serialNumber);
      if (_cachedDevice?.serialNumber == device.serialNumber) {
        _cachedDevice = null;
      }
    }
  }

  Future<void> dispose() async {
    try {
      final connectedDevices = List<String>.from(_connectedDevices);
      for (final serialNumber in connectedDevices) {
        try {
          await BitBoxFlutterApi.closeDevice(serialNumber);
        } catch (e) {
          // Ignore individual device close errors during disposal
        }
      }
      
      _connectedDevices.clear();
      _cachedDevice = null;
    } catch (e) {
      // Ignore disposal errors - we're cleaning up anyway
    }
  }
}
