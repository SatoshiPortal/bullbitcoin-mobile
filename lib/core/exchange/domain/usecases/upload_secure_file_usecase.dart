import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/secure_file_upload_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class UploadSecureFileUsecase {
  final SecureFileUploadRepository _mainnetRepository;
  final SecureFileUploadRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  UploadSecureFileUsecase({
    required SecureFileUploadRepository mainnetSecureFileUploadRepository,
    required SecureFileUploadRepository testnetSecureFileUploadRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetSecureFileUploadRepository,
        _testnetRepository = testnetSecureFileUploadRepository,
        _settingsRepository = settingsRepository;

  Future<String> execute({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      return await repo.uploadFile(
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        onProgress: onProgress,
      );
    } catch (e) {
      throw UploadSecureFileException('$e');
    }
  }
}

class UploadSecureFileException extends BullException {
  UploadSecureFileException(super.message);
}






