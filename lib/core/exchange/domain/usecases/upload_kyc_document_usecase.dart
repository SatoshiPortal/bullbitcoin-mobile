import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class UploadKycDocumentUsecase {
  final ExchangeKycRepository _mainnetRepository;
  final ExchangeKycRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  UploadKycDocumentUsecase({
    required ExchangeKycRepository mainnetRepository,
    required ExchangeKycRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<FileUploadResult> execute({
    required List<int> fileBytes,
    required String fileName,
    String docType = 'ID',
    String sourceDetail = 'SECURE_UPLOAD',
  }) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return repository.uploadDocument(
      fileBytes: fileBytes,
      fileName: fileName,
      docType: docType,
      sourceDetail: sourceDetail,
    );
  }
}

