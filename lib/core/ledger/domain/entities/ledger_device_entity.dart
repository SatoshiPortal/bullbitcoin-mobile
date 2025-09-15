import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_device_entity.freezed.dart';

enum LedgerConnectionType {
  ble,
  usb,
}

@freezed
abstract class LedgerDeviceEntity with _$LedgerDeviceEntity {
  const factory LedgerDeviceEntity({
    required String id,
    required String name,
    required LedgerConnectionType connectionType,
  }) = _LedgerDeviceEntity;

  const LedgerDeviceEntity._();
}
