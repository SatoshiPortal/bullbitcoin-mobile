import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class UnlockBitBoxDeviceUsecase {
  final BitBoxDeviceRepository _repository;

  UnlockBitBoxDeviceUsecase({required this._repository});

  @useResult
  Future<Result<String, BitBoxFailure>> execute(BitBoxDeviceEntity device) =>
      _repository.unlockDevice(device);
}
