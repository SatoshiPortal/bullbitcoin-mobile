import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_kyc_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

/// [ExchangeKycRepository] through the `bbx_api` package.
class BbxApiKycRepository implements ExchangeKycRepository {
  final bbx.Bbx _api;

  BbxApiKycRepository({required this._api});

  @override
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  }) async {
    final result = await _api.kyc.uploadDocument(
      fileBytes: fileBytes,
      fileName: fileName,
      idTypeCode: docType,
      sourceDetail: sourceDetail,
    );
    return switch (result) {
      Ok() => FileUploadResult.success(),
      Err(failure: bbx.BbxMissingCredentialFailure()) =>
        throw ApiKeyNotFoundException(),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) =>
        throw const ExchangeCredentialUnavailableException(),
      Err(:final failure) => FileUploadResult.failure(
        'Failed to upload document: ${failure.runtimeType}',
      ),
    };
  }
}
