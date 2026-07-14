import 'package:bb_mobile/core/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';

class CancelColdcardFirmwareDownloadUsecase {
  CancelColdcardFirmwareDownloadUsecase({required this._repository});

  final ColdcardFirmwareRepository _repository;

  void execute() => _repository.cancelDownload();
}
