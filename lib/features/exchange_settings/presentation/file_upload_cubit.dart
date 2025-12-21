import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/entity/file_upload_status.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_secure_file_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FileUploadCubit extends Cubit<FileUploadScreenState> {
  final UploadSecureFileUsecase _uploadSecureFileUsecase;

  FileUploadCubit({
    required UploadSecureFileUsecase uploadSecureFileUsecase,
  })  : _uploadSecureFileUsecase = uploadSecureFileUsecase,
        super(const FileUploadScreenState());

  void reset() {
    emit(const FileUploadScreenState());
  }

  void setSelectedFile(String fileName) {
    emit(state.copyWith(
      status: FileUploadStatus(
        state: FileUploadState.selecting,
        fileName: fileName,
      ),
    ));
  }

  Future<void> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    emit(state.copyWith(
      status: FileUploadStatus(
        state: FileUploadState.uploading,
        fileName: fileName,
        progress: 0.0,
      ),
      errorMessage: null,
    ));

    try {
      final fileId = await _uploadSecureFileUsecase.execute(
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        onProgress: (progress) {
          emit(state.copyWith(
            status: state.status.copyWith(progress: progress),
          ));
        },
      );

      emit(state.copyWith(
        status: FileUploadStatus(
          state: FileUploadState.success,
          fileName: fileName,
          progress: 1.0,
          uploadedFileId: fileId,
        ),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FileUploadStatus(
          state: FileUploadState.error,
          fileName: fileName,
        ),
        errorMessage: e.toString(),
      ));
    }
  }
}

