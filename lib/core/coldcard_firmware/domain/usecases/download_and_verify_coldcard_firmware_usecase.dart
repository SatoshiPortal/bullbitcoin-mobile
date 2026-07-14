import 'package:bb_mobile/core/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/coldcard_firmware_release_entity.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:bb_mobile/core/coldcard_firmware/domain/entities/verified_coldcard_firmware_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

class DownloadAndVerifyColdcardFirmwareUsecase {
  DownloadAndVerifyColdcardFirmwareUsecase({required this._repository});

  final ColdcardFirmwareRepository _repository;

  @useResult
  Future<Result<VerifiedColdcardFirmwareEntity, ColdcardFirmwareFailure>>
  execute(
    ColdcardFirmwareReleaseEntity release, {
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  }) {
    return _repository.downloadAndVerify(
      release,
      onProgress: onProgress,
      onVerifying: onVerifying,
    );
  }
}
