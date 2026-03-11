import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';

class ExchangeKycRepositoryImpl implements ExchangeKycRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;
  final BullbitcoinApiKeyDatasource _bullbitcoinApiKeyDatasource;
  final bool _isTestnet;

  ExchangeKycRepositoryImpl({
    required BullbitcoinApiDatasource bullbitcoinApiDatasource,
    required BullbitcoinApiKeyDatasource bullbitcoinApiKeyDatasource,
    required bool isTestnet,
  }) : _bullbitcoinApiDatasource = bullbitcoinApiDatasource,
       _bullbitcoinApiKeyDatasource = bullbitcoinApiKeyDatasource,
       _isTestnet = isTestnet;

  Future<String> _getApiKey() async {
    final apiKey = await _bullbitcoinApiKeyDatasource.get(isTestnet: _isTestnet);
    if (apiKey == null || !apiKey.isActive) {
      throw ApiKeyException(
        'API key not found. Please login to your Bull Bitcoin account.',
      );
    }
    return apiKey.key;
  }

  @override
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    try {
      final apiKey = await _getApiKey();

      await _bullbitcoinApiDatasource.uploadKycDocument(
        apiKey: apiKey,
        fileBytes: fileBytes,
        fileName: fileName,
        docType: docType,
        sourceDetail: sourceDetail,
      );

      return FileUploadResult.success();
    } catch (e) {
      if (e is ApiKeyException) rethrow;
      return FileUploadResult.failure('Failed to upload document: $e');
    }
  }
}

