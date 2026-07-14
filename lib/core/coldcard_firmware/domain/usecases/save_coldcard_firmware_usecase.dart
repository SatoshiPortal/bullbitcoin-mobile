import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class SaveColdcardFirmwareUsecase {
  SaveColdcardFirmwareUsecase({required this._repository});

  final ColdcardFirmwareRepository _repository;

  /// Ok(true) = saved, Ok(false) = user cancelled the destination picker.
  @useResult
  Future<Result<bool, ColdcardFirmwareFailure>> execute(
    VerifiedColdcardFirmwareEntity firmware,
  ) {
    return _repository.saveToFile(firmware);
  }
}
