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

  /// Files were rejected - can re-upload
  rejected,
}

@freezed
abstract class FileUploadState with _$FileUploadState {
  const factory FileUploadState({
    @Default(false) bool isUploading,
    @Default(false) bool isLoadingUser,
    String? error,
    @Default(false) bool uploadComplete,

    /// Whether user data was successfully loaded from the API
    @Default(false) bool isUserDataLoaded,

    /// User ID for generating standardized filenames
    String? userId,

    /// Secure file upload status from the API (from UserSummary)
    KycDocumentStatus? secureFileUploadStatus,
  }) = _FileUploadState;

  const FileUploadState._();

  /// Whether user can upload files
  /// Only allowed when data is loaded and status permits uploading
  bool get canAddMoreFiles =>
      isUserDataLoaded &&
      (secureUploadStatus == SecureUploadStatus.upload ||
          secureUploadStatus == SecureUploadStatus.rejected);

  /// Get the UI status for the secure upload feature
  /// Uses only the secureFileUploadStatus from UserSummary API response
  SecureUploadStatus get secureUploadStatus {
    // Handle each status explicitly based on API response
    switch (secureFileUploadStatus) {
      case KycDocumentStatus.accepted:
        // File was accepted - show accepted status
        return SecureUploadStatus.accepted;

      case KycDocumentStatus.underReview:
        // File is under review - cannot upload new files
        return SecureUploadStatus.inReview;

      case KycDocumentStatus.notUploaded:
        // No file uploaded yet - can upload
        return SecureUploadStatus.upload;

      case KycDocumentStatus.rejected:
        // File was rejected - show rejected status with re-upload option
        return SecureUploadStatus.rejected;

      case null:
        // Status is null - show upload button (loading state handled separately in UI)
        return SecureUploadStatus.upload;
    }
  }
}
