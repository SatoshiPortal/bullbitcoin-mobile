import 'package:bb_mobile/core/exchange/domain/entity/file_upload.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/upload_kyc_document_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  FileUploadCubit({
    required UploadKycDocumentUsecase uploadKycDocumentUsecase,
    required GetExchangeUserSummaryUsecase getExchangeUserSummaryUsecase,
  }) : _uploadKycDocumentUsecase = uploadKycDocumentUsecase,
       _getExchangeUserSummaryUsecase = getExchangeUserSummaryUsecase,
       super(const FileUploadState()) {
    _loadUserData();
  }

  final UploadKycDocumentUsecase _uploadKycDocumentUsecase;
  final GetExchangeUserSummaryUsecase _getExchangeUserSummaryUsecase;

  /// Load user data to get userId and secure file upload status
  Future<void> _loadUserData() async {
    emit(state.copyWith(isLoadingUser: true, error: null));

    try {
      final userSummary = await _getExchangeUserSummaryUsecase.execute();

      emit(
        state.copyWith(
          isLoadingUser: false,
          isUserDataLoaded: true,
          userId: userSummary.userId,
          secureFileUploadStatus:
              userSummary.kycDocumentStatus?.secureFileUpload,
        ),
      );
    } catch (e) {
      log.severe(
        message: 'Error loading user data',
        error: e,
        trace: StackTrace.current,
      );
      emit(
        state.copyWith(
          isLoadingUser: false,
          isUserDataLoaded: false,
          error: 'Failed to load user data',
        ),
      );
    }
  }

  /// Refresh user data (e.g., after upload)
  Future<void> refreshUserData() async {
    await _loadUserData();
  }

  /// Pick and upload a single file in one action (like BB-Exchange UX)
  Future<void> pickAndUploadFile() async {
    // Check if user can add more files (considering server-side count)
    if (!state.canAddMoreFiles) {
      emit(state.copyWith(error: 'A file has already been submitted.'));
      return;
    }

    emit(state.copyWith(isUploading: true, error: null));

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: FileToUpload.allowedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        emit(state.copyWith(isUploading: false));
        return;
      }

      final file = result.files.first;

      final validationResult = _validateFile(file);
      if (!validationResult.isValid) {
        emit(
          state.copyWith(
            isUploading: false,
            error: validationResult.error?.message,
          ),
        );
        return;
      }

      if (file.bytes == null) {
        emit(state.copyWith(isUploading: false, error: 'Failed to read file'));
        return;
      }

      // Generate standardized filename like BB-Exchange
      final standardizedFileName = state.userId != null
          ? 'doc-${state.userId}-ID'
          : file.name;

      final uploadResult = await _uploadKycDocumentUsecase.execute(
        fileBytes: file.bytes!,
        fileName: standardizedFileName,
      );

      if (uploadResult.isSuccess) {
        emit(state.copyWith(isUploading: false, uploadComplete: true));
        // Refresh user data to update the secure file upload status
        await refreshUserData();
      } else {
        emit(
          state.copyWith(
            isUploading: false,
            error: uploadResult.errorMessage ?? 'Upload failed',
          ),
        );
      }
    } catch (e) {
      log.severe(
        message: 'Error picking/uploading file',
        error: e,
        trace: StackTrace.current,
      );
      emit(state.copyWith(isUploading: false, error: 'Failed to upload file'));
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

  void clearError() {
    emit(state.copyWith(error: null));
  }
}
