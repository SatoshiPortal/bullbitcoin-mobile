import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart' as sdk;

part 'ledger_device_model.freezed.dart';

@freezed
abstract class LedgerDeviceModel with _$LedgerDeviceModel {
  const factory LedgerDeviceModel({
    required String id,
    required String name,
    required LedgerConnectionType connectionType,
  }) = _LedgerDeviceModel;

  const LedgerDeviceModel._();

  LedgerDeviceEntity toEntity() {
    return LedgerDeviceEntity(
      id: id,
      name: name,
      connectionType: connectionType,
    );
  }

  factory LedgerDeviceModel.fromSdkDevice(sdk.LedgerDevice device) {
    return LedgerDeviceModel(
      id: device.id,
      name: device.name,
      connectionType: device.connectionType == sdk.ConnectionType.ble
          ? LedgerConnectionType.ble
          : LedgerConnectionType.usb,
    );
  }
}

extension LedgerDeviceEntityExtension on LedgerDeviceEntity {
  LedgerDeviceModel toModel() {
    return LedgerDeviceModel(
      id: id,
      name: name,
      connectionType: connectionType,
    );
  }
}
