import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';

class ConnectBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  ConnectBitBoxDeviceUsecase({required BitBoxDeviceRepository repository})
      : _repository = repository;

  Future<void> execute(BitBoxDeviceEntity device) async {
    await _repository.connectDevice(device);
  }
}
