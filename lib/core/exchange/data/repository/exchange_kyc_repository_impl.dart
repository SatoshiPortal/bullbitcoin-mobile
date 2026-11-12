import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';

class ExchangeKycRepositoryImpl implements ExchangeKycRepository {
  final BullbitcoinApiDatasource _bullbitcoinApiDatasource;

  ExchangeKycRepositoryImpl({required this._bullbitcoinApiDatasource});

  @override
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    try {
      await _bullbitcoinApiDatasource.uploadKycDocument(
        fileBytes: fileBytes,
        fileName: fileName,
        docType: docType,
        sourceDetail: sourceDetail,
      );

      return FileUploadResult.success();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      return FileUploadResult.failure('Failed to upload document: $e');
    }
  }
}
