import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_device_entity.freezed.dart';

@freezed
abstract class LedgerDeviceEntity with _$LedgerDeviceEntity {
  const factory LedgerDeviceEntity({
    required String id,
    required String name,
  }) = _LedgerDeviceEntity;

  const LedgerDeviceEntity._();
}
