import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:meta/meta.dart';

class SaveColdcardFirmwareUsecase {
  final ColdcardFirmwareRepository _repository;

  SaveColdcardFirmwareUsecase({required this._repository});

  /// `Ok(true)` means saved; `Ok(false)` means the picker was cancelled.
  @useResult
  Future<Result<bool, ColdcardFirmwareFailure>> execute() {
    return _repository.saveVerifiedFirmware();
  }
}
