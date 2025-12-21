import 'dart:typed_data';

import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/secure_file_upload_repository.dart';

class SecureFileUploadRepositoryImpl implements SecureFileUploadRepository {
  final BullbitcoinApiDatasource _apiDatasource;
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final bool _isTestnet;

  SecureFileUploadRepositoryImpl({
    required BullbitcoinApiDatasource apiDatasource,
    required BullbitcoinApiKeyDatasource apiKeyDatasource,
    required bool isTestnet,
  })  : _apiDatasource = apiDatasource,
        _apiKeyDatasource = apiKeyDatasource,
        _isTestnet = isTestnet;

  @override
  Future<String> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final apiKeyModel = await _apiKeyDatasource.get(isTestnet: _isTestnet);

      if (apiKeyModel == null) {
        throw ApiKeyException(
          'API key not found. Please login to your Bull Bitcoin account.',
        );
      }

      if (!apiKeyModel.isActive) {
        throw ApiKeyException(
          'API key is inactive. Please login again to your Bull Bitcoin account.',
        );
      }

      final fileId = await _apiDatasource.uploadSecureFile(
        apiKey: apiKeyModel.key,
        fileName: fileName,
        fileBytes: fileBytes.toList(),
        mimeType: mimeType,
        onProgress: onProgress,
      );

      return fileId;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }
}






