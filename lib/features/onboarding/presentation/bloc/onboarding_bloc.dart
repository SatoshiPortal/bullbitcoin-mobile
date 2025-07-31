import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_bloc.freezed.dart';
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc({
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required SelectFileFromPathUsecase selectFileFromPathUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required RestoreEncryptedVaultFromBackupKeyUsecase
    restoreEncryptedVaultFromBackupKeyUsecase,
    required FetchLatestGoogleDriveBackupUsecase
    fetchLatestGoogleDriveBackupUsecase,
    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,
    required CompletePhysicalBackupVerificationUsecase
    completePhysicalBackupVerificationUsecase,
  }) : _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
       _selectFileFromPathUsecase = selectFileFromPathUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _restoreEncryptedVaultFromBackupKeyUsecase =
           restoreEncryptedVaultFromBackupKeyUsecase,
       _fetchLatestGoogleDriveBackupUsecase =
           fetchLatestGoogleDriveBackupUsecase,
       _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
       _completePhysicalBackupVerificationUsecase =
           completePhysicalBackupVerificationUsecase,
       super(const OnboardingState()) {
    on<OnboardingCreateNewWallet>(_onCreateNewWallet);
    on<OnboardingRecoverWalletClicked>(_onRecoverWalletClicked);

    on<OnboardingGoBack>((event, emit) {
      emit(state.copyWith(step: OnboardingStep.splash));
    });
    on<SelectGoogleDriveRecovery>(_onSelectGoogleDriveRecovery);
    on<SelectFileSystemRecovery>(_onSelectFileSystemRecovery);
    on<StartWalletRecovery>(_onStartWalletRecovery);

    on<StartTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: true));
    });

    on<EndTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: false));
    });
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;

  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
  _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchLatestGoogleDriveBackupUsecase
  _fetchLatestGoogleDriveBackupUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
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
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: event.mnemonic.words,
      );
      await _completePhysicalBackupVerificationUsecase.execute();
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.success));
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }

  Future<void> _fetchBackup(Emitter<OnboardingState> emit) async {
    try {
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));

      final encryptedBackup = await switch (state.vaultProvider) {
        FileSystem(:final fileAsString) => _fetchBackupFromFileSystemUsecase
            .execute(fileAsString),
        GoogleDrive() => _fetchLatestGoogleDriveBackupUsecase.execute().then(
          (result) => result.content,
        ),
        ICloud() => Future<String>.error('iCloud backup not implemented'),
      };

      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          backupInfo: encryptedBackup.backupInfo,
        ),
      );
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }

  Future<void> _onStartWalletRecovery(
    StartWalletRecovery event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));
      await _restoreEncryptedVaultFromBackupKeyUsecase.execute(
        backupFile: event.backupFile,
        backupKey: event.backupKey,
      );
      emit(
        state.copyWith(
          onboardingStepStatus: OnboardingStepStatus.success,
          step: OnboardingStep.recover,
        ),
      );
      return;
    } catch (e) {
      await _handleError(
        'Failed recover the wallet: ${event.backupFile.backupInfo.id}',
        emit,
      );
      return;
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
          vaultProvider: const VaultProvider.fileSystem(""),
        ),
      );

      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        throw Exception('No file selected');
      }

      emit(
        state.copyWith(vaultProvider: VaultProvider.fileSystem(selectedFile)),
      );

      // Then start the recover process
      await _fetchBackup(emit);
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }

  Future<void> _onSelectGoogleDriveRecovery(
    SelectGoogleDriveRecovery event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(state.copyWith(onboardingStepStatus: OnboardingStepStatus.loading));

      await _connectToGoogleDriveUsecase.execute();
      emit(state.copyWith(vaultProvider: const VaultProvider.googleDrive()));
      await _fetchBackup(emit);
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }
}
