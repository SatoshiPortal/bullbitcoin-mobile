import 'package:primitives/primitives.dart' show ScriptType;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:signers/src/signer_device_entity.dart';
import 'package:signers/src/ledger/data/models/ledger_device_model.dart';
import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger/data/ledger_exception.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart' as convert;
import 'package:flutter/foundation.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';
// ignore: implementation_imports
import 'package:ledger_bitcoin/src/psbt/map_extension.dart';
// ignore: implementation_imports
import 'package:ledger_bitcoin/src/utils/buffer_reader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sync/sync.dart' show decodeBitcoinPsbt;

class LedgerDeviceDatasource {
  LedgerInterface? _ledgerBle;
  LedgerInterface? _ledgerUsb;
  LedgerDevice? _cachedDevice;
  LedgerConnection? _cachedConnection;

  Future<List<LedgerDeviceModel>> scanDevices({
    Duration scanDuration = const Duration(seconds: 60),
    SignerDeviceEntity? deviceType,
  }) async {
    await dispose();

    final ledgerDeviceType = deviceType != null
        ? convertToLedgerDeviceType(deviceType)
        : null;
    final needsBluetooth =
        ledgerDeviceType == null || !ledgerDeviceType.usbOnly;
    if (needsBluetooth) {
      if (Platform.isAndroid) {
        final bluetoothConnectStatus = await Permission.bluetoothConnect
            .request();
        final bluetoothScanStatus = await Permission.bluetoothScan.request();

        if (!bluetoothConnectStatus.isGranted ||
            !bluetoothScanStatus.isGranted) {
          throw const PermissionDeniedLedgerException();
        }
      }

      final bleState = await UniversalBle.getBluetoothAvailabilityState();
      final bleIsEnabled = bleState == AvailabilityState.poweredOn;

      if (!bleIsEnabled) {
        throw const PermissionDeniedLedgerException();
      }
    }

    if (needsBluetooth) {
      _ledgerBle = LedgerInterface.ble(
        onPermissionRequest: (_) async {
          final Map<Permission, PermissionStatus> statuses = await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();

          return statuses.values.where((status) => status.isDenied).isEmpty;
        },
        bleOptions: BluetoothOptions(maxScanDuration: scanDuration),
      );
    }

    if (!Platform.isIOS) {
      _ledgerUsb = LedgerInterface.usb();
    }

    final devices = <LedgerDevice>[];
    final completer = Completer<void>();
    StreamSubscription<LedgerDevice>? bleScanSubscription;

    final ledgerBle = _ledgerBle;
    if (needsBluetooth && ledgerBle != null) {
      bleScanSubscription = ledgerBle.scan().listen(
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

    StreamSubscription<LedgerDevice>? usbScanSubscription;

    final ledgerUsb = _ledgerUsb;
    if (ledgerUsb != null) {
      usbScanSubscription = ledgerUsb.scan().listen(
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

    final deviceModels = devices.map((device) {
      return LedgerDeviceModel.fromLedgerDevice(device);
    }).toList();

    if (devices.length == 1) {
      _cachedDevice = devices.first;
    }
    return deviceModels;
  }

  Future<LedgerDeviceModel> connectDevice(LedgerDeviceModel device) async {
    if (_cachedConnection != null) {
      await _disconnectCurrentConnection();
    }

    final cachedDevice = _cachedDevice;
    if (cachedDevice == null || cachedDevice.id != device.id) {
      throw const DeviceNotFoundLedgerException();
    }

    LedgerInterface? ledgerInterface;
    if (device.connectionType == LedgerConnectionType.ble) {
      ledgerInterface = _ledgerBle;
    } else if (device.connectionType == LedgerConnectionType.usb) {
      ledgerInterface = _ledgerUsb;
    }

    if (ledgerInterface == null) {
      throw const ConnectionTypeNotInitializedLedgerException();
    }

    // Adding retry logic due to permission dialog not returning
    if (device.connectionType == LedgerConnectionType.usb) {
      for (int attempt = 0; attempt < 5; attempt++) {
        try {
          _cachedConnection = await ledgerInterface
              .connect(cachedDevice)
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
      _cachedConnection = await ledgerInterface.connect(cachedDevice);
    }

    return device;
  }

  LedgerConnection _getSdkConnection(LedgerDeviceModel device) {
    final connection = _cachedConnection;
    if (connection == null) {
      throw const NoActiveConnectionLedgerException();
    }

    final cachedDevice = _cachedDevice;
    if (cachedDevice == null || cachedDevice.id != device.id) {
      throw const DeviceMismatchLedgerException();
    }

    return connection;
  }

  BitcoinLedgerApp _createBitcoinApp(
    LedgerConnection connection,
    ScriptType scriptType,
    String derivationPath,
  ) {
    switch (scriptType) {
      case ScriptType.bip84:
        return BitcoinLedgerApp.nativeSegwit(
          connection,
          derivationPath: derivationPath,
        );
      case ScriptType.bip49:
        return BitcoinLedgerApp.nestedSegwit(
          connection,
          derivationPath: derivationPath,
        );
      case ScriptType.bip44:
        return BitcoinLedgerApp.legacy(
          connection,
          derivationPath: derivationPath,
        );
    }
  }

  Future<String> getXpub(
    LedgerDeviceModel device, {
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final sdkConnection = _getSdkConnection(device);
    final bitcoinApp = _createBitcoinApp(
      sdkConnection,
      scriptType,
      derivationPath,
    );

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
    required ScriptType scriptType,
  }) async {
    final sdkConnection = _getSdkConnection(device);

    final decodedPsbt = base64.decode(psbt);
    final psbtV2 = PsbtV2();
    await psbtV2.deserializeV0(decodedPsbt);

    final bitcoinApp = _createBitcoinApp(
      sdkConnection,
      scriptType,
      derivationPath,
    );

    final rawHex = await bitcoinApp.signPsbt(psbt: psbtV2);
    final finalizedTx = convert.hex.encode(rawHex);

    return finalizedTx;
  }

  Future<bool> verifyAddress(
    LedgerDeviceModel device, {
    required String address,
    required String derivationPath,
    required ScriptType scriptType,
  }) async {
    final sdkConnection = _getSdkConnection(device);
    final bitcoinApp = _createBitcoinApp(
      sdkConnection,
      scriptType,
      derivationPath,
    );
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
    final connection = _cachedConnection;
    if (connection != null) {
      try {
        await connection.disconnect();
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
      throw const InvalidMagicBytesLedgerException();
    }
    while (_readKeyPair(globalMap, bufferReader)) {}

    // Throws a FormatException when the decoder refuses the PSBT.
    final tx = decodeBitcoinPsbt(base64.encode(psbt));

    setGlobalInputCount(tx.inputs.length);
    setGlobalOutputCount(tx.outputs.length);
    setGlobalTxVersion(tx.version);

    for (var i = 0; i < getGlobalInputCount(); i++) {
      inputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(inputMaps[i], bufferReader)) {}
      final input = tx.inputDetails[i];
      setInputOutputIndex(i, input.outpoint.vout);

      setInputPreviousTxId(
        i,
        Uint8List.fromList(
          convert.hex.decode(input.outpoint.txId).reversed.toList(),
        ),
      );

      setInputSequence(i, input.sequence);
    }
    for (var i = 0; i < getGlobalOutputCount(); i++) {
      outputMaps.insert(i, <String, Uint8List>{});
      while (_readKeyPair(outputMaps[i], bufferReader)) {}
      final output = tx.outputs[i];
      setOutputAmount(i, output.valueSat);
      setOutputScript(i, Uint8List.fromList(output.scriptPubkey));
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
