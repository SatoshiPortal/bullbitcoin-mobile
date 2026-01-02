import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  FileUploadCubit({
    required UploadKycDocumentUsecase uploadKycDocumentUsecase,
  }) : _uploadKycDocumentUsecase = uploadKycDocumentUsecase,
       super(const FileUploadState());

  final UploadKycDocumentUsecase _uploadKycDocumentUsecase;

  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: FileToUpload.allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final newFiles = <UploadingFile>[];
      final currentCount = state.files.length;

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];

        if (currentCount + newFiles.length >= FileToUpload.maxFileCount) {
          emit(
            state.copyWith(
              error:
                  'Maximum ${FileToUpload.maxFileCount} files allowed. Some files were not added.',
            ),
          );
          break;
        }

        final validationResult = _validateFile(file);
        if (!validationResult.isValid) {
          emit(
            state.copyWith(
              error: '${file.name}: ${validationResult.error?.message}',
            ),
          );
          continue;
        }

        if (file.bytes != null) {
          final fileToUpload = FileToUpload(
            fileName: file.name,
            bytes: file.bytes!,
            sizeInBytes: file.size,
          );

          newFiles.add(
            UploadingFile(
              file: fileToUpload,
              status: FileUploadStatus.pending,
              index: currentCount + newFiles.length,
            ),
          );
        }
      }

      if (newFiles.isNotEmpty) {
        emit(
          state.copyWith(
            files: [...state.files, ...newFiles],
            error: null,
          ),
        );
      }
    } catch (e) {
      log.severe('Error picking files: $e');
      emit(state.copyWith(error: 'Failed to pick files'));
    }
  }

  FileValidationResult _validateFile(PlatformFile file) {
    if (file.bytes == null || file.bytes!.isEmpty) {
      return FileValidationResult.invalid(FileValidationError.emptyFile);
    }

    if (file.size > FileToUpload.maxFileSizeBytes) {
      return FileValidationResult.invalid(FileValidationError.fileTooLarge);
    }

    final extension = file.extension?.toLowerCase() ?? '';
    if (!FileToUpload.allowedExtensions.contains(extension)) {
      return FileValidationResult.invalid(FileValidationError.invalidExtension);
    }

    return FileValidationResult.valid();
  }

  void removeFile(int index) {
    final updatedFiles = state.files.where((f) => f.index != index).toList();

    final reindexedFiles = <UploadingFile>[];
    for (var i = 0; i < updatedFiles.length; i++) {
      reindexedFiles.add(updatedFiles[i].copyWith(index: i));
    }

    emit(state.copyWith(files: reindexedFiles, error: null));
  }

  Future<void> uploadFiles() async {
    if (state.files.isEmpty) {
      emit(state.copyWith(error: 'No files selected'));
      return;
    }

    emit(
      state.copyWith(
        isUploading: true,
        error: null,
        uploadComplete: false,
        uploadedCount: 0,
      ),
    );

    var uploadedCount = 0;
    final updatedFiles = <UploadingFile>[];

    for (final file in state.files) {
      final uploadingFile = file.copyWith(status: FileUploadStatus.uploading);
      emit(
        state.copyWith(
          files: [
            ...updatedFiles,
            uploadingFile,
            ...state.files.skip(updatedFiles.length + 1),
          ],
        ),
      );

      try {
        final result = await _uploadKycDocumentUsecase.execute(
          fileBytes: file.file.bytes,
          fileName: file.file.fileName,
        );

        if (result.isSuccess) {
          updatedFiles.add(file.copyWith(status: FileUploadStatus.success));
          uploadedCount++;
        } else {
          updatedFiles.add(
            file.copyWith(
              status: FileUploadStatus.failed,
              errorMessage: result.errorMessage ?? 'Upload failed',
            ),
          );
        }
      } catch (e) {
        log.severe('Error uploading file: $e');
        updatedFiles.add(
          file.copyWith(
            status: FileUploadStatus.failed,
            errorMessage: 'Upload failed',
          ),
        );
      }
    }

    emit(
      state.copyWith(
        isUploading: false,
        files: updatedFiles,
        uploadComplete: true,
        uploadedCount: uploadedCount,
      ),
    );
  }

  void clearFiles() {
    emit(const FileUploadState());
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }
}

