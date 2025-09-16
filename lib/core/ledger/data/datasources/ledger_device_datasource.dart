import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:convert/convert.dart' as convert;
import 'package:flutter/foundation.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
// ignore: implementation_imports
import 'package:ledger_bitcoin/src/psbt/map_extension.dart';
// ignore: implementation_imports
import 'package:ledger_bitcoin/src/utils/buffer_reader.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as sdk;

class LedgerDeviceDatasource {
  sdk.LedgerInterface? _ledgerBle;
  sdk.LedgerInterface? _ledgerUsb;
  sdk.LedgerDevice? _cachedDevice;
  sdk.LedgerConnection? _cachedConnection;

  Future<List<LedgerDeviceModel>> scanDevices({
    Duration scanDuration = const Duration(seconds: 60),
    SignerDeviceEntity? deviceType,
  }) async {
    await dispose();

    _ledgerBle = sdk.LedgerInterface.ble(
      onPermissionRequest: (_) async => true,
      bleOptions: sdk.BluetoothOptions(maxScanDuration: scanDuration),
    );

    if (!Platform.isIOS) {
      _ledgerUsb = sdk.LedgerInterface.usb();
    }

    final devices = <sdk.LedgerDevice>[];
    final completer = Completer<void>();
    StreamSubscription<sdk.LedgerDevice>? bleScanSubscription;

    final ledgerDeviceType =
        deviceType != null ? convertToSdkDeviceType(deviceType) : null;

    if (ledgerDeviceType == null || !ledgerDeviceType.usbOnly) {
      bleScanSubscription = _ledgerBle!.scan().listen(
        (device) {
          if (ledgerDeviceType != null &&
              device.deviceInfo != ledgerDeviceType) {
            return;
          }
          devices.add(device);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error as Object);
          }
        },
      );
    }

    StreamSubscription<sdk.LedgerDevice>? usbScanSubscription;

    if (_ledgerUsb != null) {
      usbScanSubscription = _ledgerUsb!.scan().listen(
        (device) {
          if (ledgerDeviceType != null &&
              device.deviceInfo != ledgerDeviceType) {
            return;
          }
          devices.add(device);
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error as Object);
          }
        },
      );
    }

    try {
      await completer.future.timeout(scanDuration);
    } on TimeoutException {
      // Timeout is expected if no device found
    } finally {
      await bleScanSubscription?.cancel();
      await usbScanSubscription?.cancel();
    }

    final deviceModels =
        devices.map((device) {
          return LedgerDeviceModel.fromSdkDevice(device);
        }).toList();

    if (deviceModels.isEmpty) {
      throw const LedgerError.noDevicesFound();
    }

    if (deviceModels.length > 1) {
      throw const LedgerError.multipleDevicesFound();
    }

    _cachedDevice = devices.first;
    return deviceModels;
  }

  Future<LedgerDeviceModel> connectDevice(LedgerDeviceModel device) async {
    if (_cachedConnection != null) {
      await _disconnectCurrentConnection();
    }

    if (_cachedDevice == null || _cachedDevice!.id != device.id) {
      throw const LedgerError.deviceNotFound();
    }

    sdk.LedgerInterface? ledgerInterface;
    if (device.connectionType == LedgerConnectionType.ble) {
      ledgerInterface = _ledgerBle;
    } else if (device.connectionType == LedgerConnectionType.usb) {
      ledgerInterface = _ledgerUsb;
    }

    if (ledgerInterface == null) {
      throw const LedgerError.connectionTypeNotInitialized();
    }

    // Adding retry logic due to permission dialog not returning
    if (device.connectionType == LedgerConnectionType.usb) {
      for (int attempt = 0; attempt < 5; attempt++) {
        try {
          _cachedConnection = await ledgerInterface
              .connect(_cachedDevice!)
              .timeout(const Duration(seconds: 10));
          break;
        } catch (e) {
          if (attempt == 4) {
            rethrow;
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } else {
      _cachedConnection = await ledgerInterface.connect(_cachedDevice!);
    }

    return device;
  }

  sdk.LedgerConnection _getSdkConnection(LedgerDeviceModel device) {
    if (_cachedConnection == null) {
      throw const LedgerError.noActiveConnection();
    }

    if (_cachedDevice == null || _cachedDevice!.id != device.id) {
      throw const LedgerError.deviceMismatch();
    }

    return _cachedConnection!;
  }

  Future<String> getXpub(
    LedgerDeviceModel device, {
    required String derivationPath,
  }) async {
    final sdkConnection = _getSdkConnection(device);
    final bitcoinApp = BitcoinLedgerApp(sdkConnection);

    return await bitcoinApp.getXPubKey(
      derivationPath: derivationPath,
      displayPublicKey: false,
    );
  }

  Future<String> getMasterFingerprint(LedgerDeviceModel device) async {
    final sdkConnection = _getSdkConnection(device);
    final bitcoinApp = BitcoinLedgerApp(sdkConnection);
    final fingerprint = await bitcoinApp.getMasterFingerprint();
    return fingerprint.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  Future<String> signPsbt(
    LedgerDeviceModel device, {
    required String psbt,
    required String derivationPath,
  }) async {
    final sdkConnection = _getSdkConnection(device);

    final decodedPsbt = base64.decode(psbt);
    final psbtV2 = PsbtV2();
    await psbtV2.deserializeV0(decodedPsbt);

    final bitcoinApp = BitcoinLedgerApp(
      sdkConnection,
      derivationPath: derivationPath,
    );

    final rawHex = await bitcoinApp.signPsbt(psbt: psbtV2);
    final finalizedTx = convert.hex.encode(rawHex);

    return finalizedTx;
  }

  Future<bool> verifyAddress(
    LedgerDeviceModel device, {
    required String address,
    required String derivationPath,
  }) async {
    final sdkConnection = _getSdkConnection(device);
    final bitcoinApp = BitcoinLedgerApp(sdkConnection);
    final verifiedAddress = await bitcoinApp.getAccounts(
      accountsDerivationPath: derivationPath,
      display: true,
    );

    return verifiedAddress.first == address;
  }

  Future<void> disconnectConnection(LedgerDeviceModel device) async {
    await _disconnectCurrentConnection();
  }

  Future<void> _disconnectCurrentConnection() async {
    if (_cachedConnection != null) {
      try {
        await _cachedConnection!.disconnect();
      } catch (e) {
        log.info('Error disconnecting Ledger device', error: e);
      }
      _cachedConnection = null;
    }
  }

  Future<void> dispose() async {
    await _disconnectCurrentConnection();
    _cachedDevice = null;
    _ledgerBle = null;
    _ledgerUsb = null;
  }
}

extension PsbtSigner on PsbtV2 {
  Future<void> deserializeV0(Uint8List psbt) async {
    final bufferReader = BufferReader(psbt);
    if (!listEquals(
      bufferReader.readSlice(5),
      Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff]),
    )) {
      throw const LedgerError.invalidMagicBytes();
    }
    while (_readKeyPair(globalMap, bufferReader)) {}

    final bdkPsbt = await bdk.PartiallySignedTransaction.fromString(
      base64.encode(psbt),
    );
    final tx = bdkPsbt.extractTx();

    setGlobalInputCount(tx.input().length);
    setGlobalOutputCount(tx.output().length);
    setGlobalTxVersion(tx.version());

    for (var i = 0; i < getGlobalInputCount(); i++) {
      inputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(inputMaps[i], bufferReader)) {}
      final input = tx.input()[i];
      setInputOutputIndex(i, input.previousOutput.vout);

      setInputPreviousTxId(
        i,
        Uint8List.fromList(
          convert.hex.decode(input.previousOutput.txid).reversed.toList(),
        ),
      );

      setInputSequence(i, input.sequence);
    }
    for (var i = 0; i < getGlobalOutputCount(); i++) {
      outputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(outputMaps[i], bufferReader)) {}
      final output = tx.output()[i];
      setOutputAmount(i, output.value.toInt());
      setOutputScript(i, Uint8List.fromList(output.scriptPubkey.bytes));
    }
  }

  bool _readKeyPair(Map<String, Uint8List> map, BufferReader bufferReader) {
    final keyLen = bufferReader.readVarInt();
    if (keyLen == 0) return false;

    final keyType = bufferReader.readUInt8();
    final keyData = bufferReader.readSlice(keyLen - 1);
    final value = bufferReader.readVarSlice();

    map.set(keyType, keyData, value);
    return true;
  }
}
