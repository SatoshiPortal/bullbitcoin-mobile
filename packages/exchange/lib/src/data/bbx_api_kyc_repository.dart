import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart';

import '../domain/exchange_failure.dart';

final class BbxApiKycRepository {
  final bbx.Bbx _api;

  const BbxApiKycRepository({required this._api});

  Future<Result<void, ExchangeFailure>> uploadDocument({
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
      Ok() => const Ok(null),
      Err(failure: bbx.BbxMissingCredentialFailure()) => const Err(
        ExchangeNotAuthenticatedFailure(),
      ),
      Err(failure: bbx.BbxCredentialUnavailableFailure()) => const Err(
        ExchangeCredentialReadFailure(),
      ),
      Err(:final failure) => Err(
        ExchangeDocumentUploadFailure('Failed to upload document: $failure'),
      ),
    };
  }
}
