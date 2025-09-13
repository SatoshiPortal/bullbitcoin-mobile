import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_device_model.freezed.dart';

@freezed
abstract class LedgerDeviceModel with _$LedgerDeviceModel {
  const factory LedgerDeviceModel({
    required String id,
    required String name,
  }) = _LedgerDeviceModel;

  const LedgerDeviceModel._();

  LedgerDeviceEntity toEntity() {
    return LedgerDeviceEntity(
      id: id,
      name: name,
    );
  }
}

extension LedgerDeviceEntityExtension on LedgerDeviceEntity {
  LedgerDeviceModel toModel() {
    return LedgerDeviceModel(
      id: id,
      name: name,
    );
  }
}
