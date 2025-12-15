import 'package:bb_mobile/core_deprecated/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core_deprecated/bitbox/domain/repositories/bitbox_device_repository.dart';

class ScanBitBoxDevicesUsecase {
  final BitBoxDeviceRepository _repository;

  ScanBitBoxDevicesUsecase({required BitBoxDeviceRepository repository})
    : _repository = repository;

  Future<List<BitBoxDeviceEntity>> execute() async {
    return await _repository.scanDevices();
  }
}
