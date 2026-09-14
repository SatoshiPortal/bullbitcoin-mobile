import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_settings_account_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/upload_exchange_document_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/file_upload_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class FileUploadCubit extends Cubit<FileUploadState> {
  final GetExchangeSettingsAccountUsecase _getExchangeSettingsAccountUsecase;
  final UploadExchangeDocumentUsecase _uploadExchangeDocumentUsecase;

  FileUploadCubit({
    required GetExchangeSettingsAccountUsecase getAccountUsecase,
    required UploadExchangeDocumentUsecase uploadDocumentUsecase,
  }) : _getExchangeSettingsAccountUsecase = getAccountUsecase,
       _uploadExchangeDocumentUsecase = uploadDocumentUsecase,
       super(const FileUploadState()) {
    _loadUserData();
  }

  /// Refresh user data (e.g., after upload)
  Future<void> refreshUserData() async {
    await _loadUserData();
  }

  /// Pick and upload a single file in one action (like BB-Exchange UX)
  Future<void> pickAndUploadFile() async {
    if (!state.canAddMoreFiles) {
      emit(
        state.copyWith(
          failure: const ExchangeSettingsDocumentAlreadySubmittedFailure(),
        ),
      );
      return;
    }

    emit(state.copyWith(isUploading: true, failure: null));

    final result = await _uploadExchangeDocumentUsecase.execute(
      userId: state.userId,
    );
    if (isClosed) return;

    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(isUploading: false, failure: failure));
      case Ok(:final value):
        switch (value) {
          case ExchangeDocumentPickCancelled():
            emit(state.copyWith(isUploading: false));
          case ExchangeDocumentUploaded():
            emit(state.copyWith(isUploading: false, uploadComplete: true));
            // Refresh so the screen reflects the new review status.
            await refreshUserData();
        }
    }
  }

  void clearError() {
    emit(state.copyWith(failure: null));
  }

  /// Load user data to get userId and secure file upload status
  Future<void> _loadUserData() async {
    emit(state.copyWith(isLoadingUser: true, failure: null));

    final result = await _getExchangeSettingsAccountUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        isLoadingUser: false,
        isUserDataLoaded: true,
        userId: value.userId,
        secureFileUploadStatus: value.kycDocumentStatus?.secureFileUpload,
      ),
      Err(:final failure) => state.copyWith(
        isLoadingUser: false,
        isUserDataLoaded: false,
        failure: failure,
      ),
    });
  }
}
