import 'package:bb_mobile/core_deprecated/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitbox_device_model.freezed.dart';

@freezed
abstract class BitBoxDeviceModel with _$BitBoxDeviceModel {
  const factory BitBoxDeviceModel({
    required String deviceName,
    required String serialNumber,
    required String product,
    required BitBoxConnectionType connectionType,
    String? fingerprint,
  }) = _BitBoxDeviceModel;

  const BitBoxDeviceModel._();

  BitBoxDeviceEntity toEntity() {
    return BitBoxDeviceEntity(
      deviceName: deviceName,
      serialNumber: serialNumber,
      product: product,
      connectionType: connectionType,
      fingerprint: fingerprint,
    );
  }

  factory BitBoxDeviceModel.fromBitBoxDevice({
    required String deviceName,
    required String serialNumber,
    required String product,
    required BitBoxConnectionType connectionType,
    String? fingerprint,
  }) {
    return BitBoxDeviceModel(
      deviceName: deviceName,
      serialNumber: serialNumber,
      product: product,
      connectionType: connectionType,
      fingerprint: fingerprint,
    );
  }
}

extension BitBoxDeviceEntityExtension on BitBoxDeviceEntity {
  BitBoxDeviceModel toModel() {
    return BitBoxDeviceModel(
      deviceName: deviceName,
      serialNumber: serialNumber,
      product: product,
      connectionType: connectionType,
      fingerprint: fingerprint,
    );
  }
}
