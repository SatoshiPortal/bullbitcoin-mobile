import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';

class PairBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  PairBitBoxDeviceUsecase({required BitBoxDeviceRepository repository})
      : _repository = repository;

  Future<String> execute(BitBoxDeviceEntity device) async {
    return await _repository.pairDevice(device);
  }
}
