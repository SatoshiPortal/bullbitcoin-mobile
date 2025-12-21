import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_upload_status.freezed.dart';

/// Status of a file upload operation
enum FileUploadState {
  idle,
  selecting,
  uploading,
  success,
  error,
}

/// Represents the status of a secure file upload
@freezed
sealed class FileUploadStatus with _$FileUploadStatus {
  const FileUploadStatus._();

  const factory FileUploadStatus({
    @Default(FileUploadState.idle) FileUploadState state,
    @Default(0.0) double progress,
    String? fileName,
    String? errorMessage,
    String? uploadedFileId,
  }) = _FileUploadStatus;

  /// Whether the upload is currently in progress
  bool get isUploading => state == FileUploadState.uploading;

  /// Whether the upload completed successfully
  bool get isSuccess => state == FileUploadState.success;

  /// Whether there was an error
  bool get hasError => state == FileUploadState.error;

  /// Progress as a percentage string
  String get progressPercentage => '${(progress * 100).toStringAsFixed(0)}%';
}

