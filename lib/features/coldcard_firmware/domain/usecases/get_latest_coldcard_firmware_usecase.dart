import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart'
    show ColdcardModel, FirmwareRelease;
import 'package:meta/meta.dart';

class GetLatestColdcardFirmwareUsecase {
  final ColdcardFirmwareRepository _repository;

  GetLatestColdcardFirmwareUsecase({required this._repository});

  @useResult
  Future<Result<FirmwareRelease, ColdcardFirmwareFailure>> execute(
    ColdcardModel model,
  ) {
    return _repository.fetchLatest(model);
  }
}
