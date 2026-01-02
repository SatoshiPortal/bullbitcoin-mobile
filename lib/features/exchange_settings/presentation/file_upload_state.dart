import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_upload_state.freezed.dart';

@freezed
abstract class FileUploadState with _$FileUploadState {
  const factory FileUploadState({
    @Default([]) List<UploadingFile> files,
    @Default(false) bool isUploading,
    String? error,
    @Default(false) bool uploadComplete,
    @Default(0) int uploadedCount,
  }) = _FileUploadState;

  const FileUploadState._();

  bool get hasFiles => files.isNotEmpty;

  bool get canAddMoreFiles => files.length < FileToUpload.maxFileCount;

  int get pendingCount =>
      files.where((f) => f.status == FileUploadStatus.pending).length;

  int get failedCount =>
      files.where((f) => f.status == FileUploadStatus.failed).length;

  bool get hasFailures => failedCount > 0;

  bool get allUploaded =>
      files.isNotEmpty &&
      files.every((f) => f.status == FileUploadStatus.success);
}

