import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';

/// Model for KYC document upload request
class KycUploadRequestModel {
  final String fileName;
  final List<int> fileBytes;
  final KycDocType docType;
  final KycSourceDetail sourceDetail;

  const KycUploadRequestModel({
    required this.fileName,
    required this.fileBytes,
    required this.docType,
    required this.sourceDetail,
  });

  String get docTypeValue {
    switch (docType) {
      case KycDocType.id:
        return 'ID';
      case KycDocType.proofOfAddress:
        return 'PROOF_OF_ADDRESS';
      case KycDocType.other:
        return 'OTHER';
    }
  }

  String get sourceDetailValue {
    switch (sourceDetail) {
      case KycSourceDetail.secureUpload:
        return 'SECURE_UPLOAD';
      case KycSourceDetail.kyc:
        return 'KYC';
    }
  }
}

/// Enum for KYC document types
enum KycDocType {
  id,
  proofOfAddress,
  other,
}

/// Enum for KYC source details
enum KycSourceDetail {
  secureUpload,
  kyc,
}

/// Model for KYC upload response
class KycUploadResponseModel {
  final String? documentId;
  final String? status;

  const KycUploadResponseModel({
    this.documentId,
    this.status,
  });

  factory KycUploadResponseModel.fromJson(Map<String, dynamic> json) {
    return KycUploadResponseModel(
      documentId: json['documentId'] as String?,
      status: json['status'] as String?,
    );
  }

  FileUploadResult toEntity() {
    return FileUploadResult(
      documentId: documentId,
      isSuccess: status == 'SUCCESS' || documentId != null,
    );
  }
}

