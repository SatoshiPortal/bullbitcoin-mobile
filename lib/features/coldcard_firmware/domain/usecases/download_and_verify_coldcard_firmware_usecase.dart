import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/coldcard_firmware_failure.dart';
import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';
import 'package:meta/meta.dart';

class DownloadAndVerifyColdcardFirmwareUsecase {
  final ColdcardFirmwareRepository _repository;

  DownloadAndVerifyColdcardFirmwareUsecase({required this._repository});

  @useResult
  Future<Result<void, ColdcardFirmwareFailure>> execute({
    void Function(int received, int? total)? onProgress,
    void Function()? onVerifying,
  }) {
    return _repository.downloadAndVerify(
      onProgress: onProgress,
      onVerifying: onVerifying,
    );
  }
}
