import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';

class UnlockBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  UnlockBitBoxDeviceUsecase({required BitBoxDeviceRepository repository})
      : _repository = repository;

  Future<String> execute(BitBoxDeviceEntity device) async {
    return await _repository.unlockDevice(device);
  }
}
