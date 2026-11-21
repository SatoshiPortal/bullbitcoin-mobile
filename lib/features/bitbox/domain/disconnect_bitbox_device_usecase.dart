import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:primitives/primitives.dart';

class DisconnectBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;
  DisconnectBitBoxDeviceUsecase({required this._repository});
  Future<Result<void, BitBoxFailure>> execute(BitBoxDeviceEntity device) =>
      _repository.disconnectConnection(device);
}
