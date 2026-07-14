import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_device.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class GetLatestColdcardFirmwareUsecase {
  GetLatestColdcardFirmwareUsecase({required this._repository});

  final ColdcardFirmwareRepository _repository;

  @useResult
  Future<Result<ColdcardFirmwareReleaseEntity, ColdcardFirmwareFailure>>
  execute(ColdcardDevice device) {
    return _repository.fetchLatest(device);
  }
}
