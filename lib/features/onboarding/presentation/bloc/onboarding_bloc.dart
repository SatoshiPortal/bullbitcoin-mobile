import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_cloud_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_preview_wallets_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_all_google_drive_backups_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_google_drive_backup_content_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required FindMnemonicWordsUsecase findMnemonicWordsUsecase,
    required SelectFileFromPathUsecase selectFileFromPathUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required RestoreEncryptedVaultFromBackupKeyUsecase
    restoreEncryptedVaultFromBackupKeyUsecase,

    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,

    required CompletePhysicalBackupVerificationUsecase
    completePhysicalBackupVerificationUsecase,
    required CompleteCloudBackupVerificationUsecase
    completeCloudBackupVerificationUsecase,
    required FetchAllGoogleDriveBackupsUsecase
    fetchAllGoogleDriveBackupsUsecase,
    required FetchGoogleDriveBackupContentUsecase
    fetchGoogleDriveBackupContentUsecase,
    required CreatePreviewWalletsUsecase createPreviewWalletsUsecase,
  }) : _createDefaultWalletsUsecase = createDefaultWalletsUsecase,

       _findMnemonicWordsUsecase = findMnemonicWordsUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _restoreEncryptedVaultFromBackupKeyUsecase =
           restoreEncryptedVaultFromBackupKeyUsecase,
       _fetchGoogleDriveBackupContentUsecase =
           fetchGoogleDriveBackupContentUsecase,
       _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
       _completePhysicalBackupVerificationUsecase =
           completePhysicalBackupVerificationUsecase,
       _completeCloudBackupVerificationUsecase =
           completeCloudBackupVerificationUsecase,
       _fetchAllGoogleDriveBackupsUsecase = fetchAllGoogleDriveBackupsUsecase,
       _createPreviewWalletsUsecase = createPreviewWalletsUsecase,
       super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoveryWordChanged>(_onRecoveryWordChanged);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
    on<SelectGoogleDriveRecovery>(_onSelectGoogleDriveRecovery);
    on<SelectFileSystemRecovery>(_onSelectFileSystemRecovery);
    on<StartWalletRecovery>(_onStartWalletRecovery);
    on<FetchAllGoogleDriveBackups>(_onFetchAllGoogleDriveBackups);
    on<SelectCloudBackupToFetch>(_onSelectCloudBackupToFetch);
    on<PersistRecoveredWallets>(_onPersistRecoveredWallets);
    on<StartTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: true));
    });

    on<EndTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: false));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final FindMnemonicWordsUsecase _findMnemonicWordsUsecase;
  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
  _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;
  final FetchGoogleDriveBackupContentUsecase
  _fetchGoogleDriveBackupContentUsecase;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  final CompleteCloudBackupVerificationUsecase
  _completeCloudBackupVerificationUsecase;
  final CreatePreviewWalletsUsecase _createPreviewWalletsUsecase;
  final FetchAllGoogleDriveBackupsUsecase _fetchAllGoogleDriveBackupsUsecase;
  Future<void> _handleError(String error, Emitter<OnboardingState> emit) async {
    log.severe('Error: $error');
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.none,
        statusError: error,
      ),
    );
  }

  Future<void> _onCreateNewWallet(
    OnboardingCreateNewWallet event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.create,
        ),
      );
      await Future.delayed(const Duration(seconds: 2));

      await _createDefaultWalletsUsecase.execute();
      await Future.delayed(const Duration(seconds: 2));
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }

  Future<void> _onRecoveryWordChanged(
    OnboardingRecoveryWordChanged event,
    Emitter<OnboardingState> emit,
  ) async {
    final wordIndex = event.index;
    final word = event.word;
    final validWords = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);

    hintWords[wordIndex] = _findMnemonicWordsUsecase.execute(word);

    if (hintWords[wordIndex]?.contains(word) == true) {
      validWords[event.index] = event.word;
    } else {
      validWords.remove(event.index);
    }

    emit(state.copyWith(validWords: validWords, hintWords: hintWords));
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          step: OnboardingStep.recover,
        ),
      );
      emit(state.copyWith(hintWords: {}));

      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: state.validWords.values.toList(),
      );
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }

  Future<void> _onStartWalletRecovery(
    StartWalletRecovery event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.loading,
        statusError: '',
      ),
    );

    try {
      final recoverBullWallet = await _restoreEncryptedVaultFromBackupKeyUsecase
          .execute(backupFile: event.backupFile, backupKey: event.backupKey);
      final recoverdWalletPreviews = await _createPreviewWalletsUsecase.execute(
        mnemonicWords: recoverBullWallet.mnemonic,
      );
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          step: OnboardingStep.recover,
          recoveredWallets: (
            recoverBullWallet.mnemonic,
            recoverdWalletPreviews,
          ),
        ),
      );
    } on DefaultWalletExistsError catch (e) {
      await _handleError(e.toString(), emit);
    } catch (e) {
      log.severe('Failed to create wallet: $e');
      await _handleError('Failed to recover backup', emit);
    }
  }

  Future<void> _onSelectFileSystemRecovery(
    SelectFileSystemRecovery event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          vaultProvider: const VaultProvider.fileSystem(''),
        ),
      );

      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        throw Exception('No file selected');
      }

      final encryptedBackup = await _fetchBackupFromFileSystemUsecase.execute(
        selectedFile,
      );
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          selectedBackup: encryptedBackup,
        ),
      );
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }

  Future<void> _onSelectGoogleDriveRecovery(
    SelectGoogleDriveRecovery event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.loading,
          vaultProvider: const VaultProvider.googleDrive(),
        ),
      );
      await _connectToGoogleDriveUsecase.execute();
      add(const FetchAllGoogleDriveBackups());
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }

  Future<void> _onFetchAllGoogleDriveBackups(
    FetchAllGoogleDriveBackups event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));
      final driveFiles = await _fetchAllGoogleDriveBackupsUsecase.execute();
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          availableCloudBackups: driveFiles,
        ),
      );
    } catch (e) {
      await _handleError('Failed to fetch backups: $e', emit);
    }
  }

  Future<void> _onSelectCloudBackupToFetch(
    SelectCloudBackupToFetch event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));
    try {
      final encryptedBackup = await _fetchGoogleDriveBackupContentUsecase
          .execute(event.id);
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          selectedBackup: encryptedBackup,
        ),
      );
    } catch (e) {
      await _handleError('Failed to fetch backup content: $e', emit);
    }
  }

  Future<void> _onPersistRecoveredWallets(
    PersistRecoveredWallets event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));

      await _createDefaultWalletsUsecase.execute(mnemonicWords: event.mnemonic);

      await _completeCloudBackupVerificationUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }
}
