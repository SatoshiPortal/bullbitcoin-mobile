import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
import 'package:bb_mobile/core_deprecated/ledger/domain/entities/ledger_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';

part 'ledger_device_model.freezed.dart';

LedgerDeviceType convertToLedgerDeviceType(SignerDeviceEntity deviceType) {
  switch (deviceType) {
    case SignerDeviceEntity.ledgerNanoSPlus:
      return LedgerDeviceType.nanoSP;
    case SignerDeviceEntity.ledgerNanoX:
      return LedgerDeviceType.nanoX;
    case SignerDeviceEntity.ledgerFlex:
      return LedgerDeviceType.flex;
    case SignerDeviceEntity.ledgerStax:
      return LedgerDeviceType.stax;
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
    required LedgerDeviceType deviceType,
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

  factory LedgerDeviceModel.fromLedgerDevice(LedgerDevice device) {
    return LedgerDeviceModel(
      id: device.id,
      name: device.name,
      connectionType:
          device.connectionType == ConnectionType.ble
              ? LedgerConnectionType.ble
              : LedgerConnectionType.usb,
      deviceType: device.deviceInfo,
    );
  }

  static SignerDeviceEntity _convertToSignerDeviceType(
    LedgerDeviceType deviceType,
  ) {
    switch (deviceType) {
      case LedgerDeviceType.nanoSP:
        return SignerDeviceEntity.ledgerNanoSPlus;
      case LedgerDeviceType.nanoX:
        return SignerDeviceEntity.ledgerNanoX;
      case LedgerDeviceType.flex:
        return SignerDeviceEntity.ledgerFlex;
      case LedgerDeviceType.stax:
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
      deviceType: convertToLedgerDeviceType(deviceType),
    );
  }
}
