import 'package:bb_mobile/core/bitbox/domain/entities/bitbox_device_entity.dart';
import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_failure.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class ScanBitBoxDevicesUsecase {
  final BitBoxDeviceRepository _repository;

  ScanBitBoxDevicesUsecase({required this._repository});

  @useResult
  Future<Result<List<BitBoxDeviceEntity>, BitBoxFailure>> execute() async {
    switch (await _repository.scanDevices()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return value.isEmpty
            ? const Err(NoDevicesFoundBitBoxFailure())
            : Ok(value);
    }
  }
}
