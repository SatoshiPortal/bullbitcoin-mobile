import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_upload_state.freezed.dart';

/// Status for the secure file upload UI (matches BB-Exchange DocStatus)
enum SecureUploadStatus {
  /// Files can be uploaded
  upload,

  /// Files are under review
  inReview,

  /// Files have been accepted
  accepted,
}

@freezed
abstract class FileUploadState with _$FileUploadState {
  const factory FileUploadState({
    @Default(false) bool isUploading,
    @Default(false) bool isLoadingUser,
    String? error,
    @Default(false) bool uploadComplete,

    /// User ID for generating standardized filenames
    String? userId,

    /// Secure file upload status from the API
    KycDocumentStatus? secureFileUploadStatus,

    /// Number of files already submitted on the server
    @Default(0) int serverSubmittedCount,
  }) = _FileUploadState;

  const FileUploadState._();

  /// Whether user can add more files (only 1 file allowed now)
  bool get canAddMoreFiles =>
      serverSubmittedCount < FileToUpload.maxFileCount &&
      secureUploadStatus == SecureUploadStatus.upload;

  /// Get the UI status for the secure upload feature
  SecureUploadStatus get secureUploadStatus {
    // If status from API indicates accepted, show accepted
    if (secureFileUploadStatus == KycDocumentStatus.accepted) {
      return SecureUploadStatus.accepted;
    }

    // If status from API indicates under review OR max files submitted, show in review
    if (secureFileUploadStatus == KycDocumentStatus.underReview ||
        serverSubmittedCount >= FileToUpload.maxFileCount) {
      return SecureUploadStatus.inReview;
    }

    // Otherwise, can upload
    return SecureUploadStatus.upload;
  }
}
