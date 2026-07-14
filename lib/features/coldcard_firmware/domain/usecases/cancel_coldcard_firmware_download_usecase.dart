import 'package:bb_mobile/features/coldcard_firmware/domain/repositories/coldcard_firmware_repository.dart';

class CancelColdcardFirmwareDownloadUsecase {
  final ColdcardFirmwareRepository _repository;

  CancelColdcardFirmwareDownloadUsecase({required this._repository});

  void execute() => _repository.cancelDownload();
}
