import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';

abstract class ExchangeKycRepository {
  /// Upload a KYC document file
  Future<FileUploadResult> uploadDocument({
    required List<int> fileBytes,
    required String fileName,
    required String docType,
    required String sourceDetail,
  });
}

