import 'dart:async';
import 'dart:convert';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
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
  sdk.LedgerDevice? _cachedDevice;
  sdk.LedgerConnection? _cachedConnection;

  Future<List<LedgerDeviceModel>> scanDevices({
    Duration scanDuration = const Duration(seconds: 60),
  }) async {
    if (_ledgerBle != null) {
      await dispose();
    }

    _ledgerBle = sdk.LedgerInterface.ble(
      onPermissionRequest: (_) async => true,
      bleOptions: sdk.BluetoothOptions(maxScanDuration: scanDuration),
    );

    final devices = <sdk.LedgerDevice>[];
    final completer = Completer<void>();
    StreamSubscription<sdk.LedgerDevice>? scanSubscription;
    
    scanSubscription = _ledgerBle!.scan().listen(
      (device) {
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

    try {
      await completer.future.timeout(scanDuration);
    } on TimeoutException {
      // Timeout is expected if no device found
    } finally {
      await scanSubscription.cancel();
    }

    final deviceModels =
        devices.map((device) {
          return LedgerDeviceModel(id: device.id, name: device.name);
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

    if (_ledgerBle == null) {
      throw Exception('Bluetooth interface not initialized');
    }

    if (_cachedDevice == null || _cachedDevice!.id != device.id) {
      throw Exception(
        'Device not found in cache. Please scan for devices first.',
      );
    }

    _cachedConnection = await _ledgerBle!.connect(_cachedDevice!);
    return device;
  }

  sdk.LedgerConnection _getSdkConnection(LedgerDeviceModel device) {
    if (_cachedConnection == null) {
      throw Exception(
        'No active connection. Please connect to a device first.',
      );
    }

    if (_cachedDevice == null || _cachedDevice!.id != device.id) {
      throw Exception(
        'Device mismatch. Connected device does not match the requested device.',
      );
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
        log.warning('Error disconnecting Ledger device', error: e);
      }
      _cachedConnection = null;
    }
  }

  Future<void> dispose() async {
    await _disconnectCurrentConnection();
    _cachedDevice = null;
    _ledgerBle = null;
  }
}

extension PsbtSigner on PsbtV2 {
  Future<void> deserializeV0(Uint8List psbt) async {
    final bufferReader = BufferReader(psbt);
    if (!listEquals(
      bufferReader.readSlice(5),
      Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff]),
    )) {
      throw Exception("Invalid magic bytes");
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
