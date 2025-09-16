import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as sdk;

part 'ledger_device_model.freezed.dart';

sdk.LedgerDeviceType convertToSdkDeviceType(SignerDeviceEntity deviceType) {
  switch (deviceType) {
    case SignerDeviceEntity.ledgerNanoSPlus:
      return sdk.LedgerDeviceType.nanoSP;
    case SignerDeviceEntity.ledgerNanoX:
      return sdk.LedgerDeviceType.nanoX;
    case SignerDeviceEntity.ledgerFlex:
      return sdk.LedgerDeviceType.flex;
    case SignerDeviceEntity.ledgerStax:
      return sdk.LedgerDeviceType.stax;
    default:
      throw Exception('Unsupported Ledger device');
  }
}

@freezed
abstract class LedgerDeviceModel with _$LedgerDeviceModel {
  const factory LedgerDeviceModel({
    required String id,
    required String name,
    required LedgerConnectionType connectionType,
    required sdk.LedgerDeviceType deviceType,
  }) = _LedgerDeviceModel;

  const LedgerDeviceModel._();

  LedgerDeviceEntity toEntity() {
    return LedgerDeviceEntity(
      id: id,
      name: name,
      connectionType: connectionType,
      deviceType: _convertToSignerDeviceType(deviceType),
    );
  }

  factory LedgerDeviceModel.fromSdkDevice(sdk.LedgerDevice device) {
    return LedgerDeviceModel(
      id: device.id,
      name: device.name,
      connectionType:
          device.connectionType == sdk.ConnectionType.ble
              ? LedgerConnectionType.ble
              : LedgerConnectionType.usb,
      deviceType: device.deviceInfo,
    );
  }

  static SignerDeviceEntity _convertToSignerDeviceType(
    sdk.LedgerDeviceType deviceType,
  ) {
    switch (deviceType) {
      case sdk.LedgerDeviceType.nanoSP:
        return SignerDeviceEntity.ledgerNanoSPlus;
      case sdk.LedgerDeviceType.nanoX:
        return SignerDeviceEntity.ledgerNanoX;
      case sdk.LedgerDeviceType.flex:
        return SignerDeviceEntity.ledgerFlex;
      case sdk.LedgerDeviceType.stax:
        return SignerDeviceEntity.ledgerStax;
      default:
        throw Exception('Unsupported Ledger device');
    }
  }
}

extension LedgerDeviceEntityExtension on LedgerDeviceEntity {
  LedgerDeviceModel toModel() {
    return LedgerDeviceModel(
      id: id,
      name: name,
      connectionType: connectionType,
      deviceType: convertToSdkDeviceType(deviceType),
    );
  }
}
