import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;

/// [ExchangeKycRepository] through the `bbx_api` package.
class BbxApiKycRepository implements ExchangeKycRepository {
  final bbx.BbxApiClient _api;

  BbxApiKycRepository({required this._api});

  @override
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    try {
      await _api.kyc.uploadDocument(
        fileBytes: fileBytes,
        fileName: fileName,
        idTypeCode: docType,
        sourceDetail: sourceDetail,
      );
      return FileUploadResult.success();
    } catch (e, st) {
      rethrowExchangeAuthentication(e, st);
      if (e is ApiKeyException) rethrow;
      // A server rejection is logged by type: its message is the server's.
      final reason = e is bbx.BbxApiRpcException ? e.runtimeType : e;
      return FileUploadResult.failure('Failed to upload document: $reason');
    }
  }
}
