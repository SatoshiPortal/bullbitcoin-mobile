import 'package:bb_mobile/core/exchange/domain/entity/file_upload_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_upload_state.freezed.dart';

@freezed
sealed class FileUploadScreenState with _$FileUploadScreenState {
  const FileUploadScreenState._();

  const factory FileUploadScreenState({
    @Default(FileUploadStatus()) FileUploadStatus status,
    String? errorMessage,
  }) = _FileUploadScreenState;

  bool get isIdle => status.state == FileUploadState.idle;
  bool get isUploading => status.isUploading;
  bool get isSuccess => status.isSuccess;
  bool get hasError => status.hasError || errorMessage != null;
  double get progress => status.progress;
  String? get fileName => status.fileName;
}

