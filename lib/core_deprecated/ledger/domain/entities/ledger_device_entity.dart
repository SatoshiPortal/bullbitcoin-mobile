import 'package:bb_mobile/core_deprecated/entities/signer_device_entity.dart';
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
    required SignerDeviceEntity deviceType,
  }) = _LedgerDeviceEntity;

  const LedgerDeviceEntity._();
}
