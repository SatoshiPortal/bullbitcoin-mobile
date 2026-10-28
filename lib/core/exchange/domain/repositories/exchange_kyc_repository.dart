import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';

abstract class ExchangeKycRepository {
  /// Uploads a photo ID document through the secure file upload.
  Future<FileUploadResult> uploadSecureIdDocument({
    required List<int> fileBytes,
    required String fileName,
  });
}
