import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bbx_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// [ExchangeKycRepository] on the shared `bbx_api` client.
class BbxApiExchangeKycRepository implements ExchangeKycRepository {
  final BbxApiDatasource _api;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  BbxApiExchangeKycRepository({
    required this._api,
    required this._apiKeyDatasource,
    required this._isTestnet,
  });

  @override
  Future<FileUploadResult> uploadSecureIdDocument({
    required List<int> fileBytes,
    required String fileName,
  }) async {
    final apiKey = await _apiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }

    try {
      final result = await _api.kyc.uploadDocumentFile(
        bbx.UploadKycDocsPayload(
          fileName: fileName,
          bytes: fileBytes,
          docType: bbx.DocTypeCode.id,
          source: bbx.SourceDetail.secureUpload,
        ),
      );
      return switch (result) {
        bbx.Success() => FileUploadResult.success(),
        bbx.Failure(:final error) => FileUploadResult.failure(
          'Failed to upload document: '
          '${BbxApiException(error..reportBadCertificate())}',
        ),
      };
    } catch (e) {
      return FileUploadResult.failure(
        'Failed to upload document: ${e.runtimeType}',
      );
    }
  }
}
