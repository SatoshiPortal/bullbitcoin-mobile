import 'package:freezed_annotation/freezed_annotation.dart';

part 'bitbox_device_entity.freezed.dart';

enum BitBoxConnectionType {
  usb,
}

@freezed
abstract class BitBoxDeviceEntity with _$BitBoxDeviceEntity {
  const factory BitBoxDeviceEntity({
    required String deviceName,
    required String serialNumber,
    required String product,
    required BitBoxConnectionType connectionType,
    String? fingerprint,
  }) = _BitBoxDeviceEntity;

  const BitBoxDeviceEntity._();
}
