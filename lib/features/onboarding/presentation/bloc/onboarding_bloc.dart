import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/features/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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
    required FetchLatestGoogleDriveBackupUsecase
        fetchLatestGoogleDriveBackupUsecase,
    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,
  })  : _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
        _findMnemonicWordsUsecase = findMnemonicWordsUsecase,
        _selectFileFromPathUsecase = selectFileFromPathUsecase,
        _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
        _restoreEncryptedVaultFromBackupKeyUsecase =
            restoreEncryptedVaultFromBackupKeyUsecase,
        _fetchLatestGoogleDriveBackupUsecase =
            fetchLatestGoogleDriveBackupUsecase,
        _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
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
  }

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final FindMnemonicWordsUsecase _findMnemonicWordsUsecase;

  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
      _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchLatestGoogleDriveBackupUsecase
      _fetchLatestGoogleDriveBackupUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;

  Future<void> _handleError(
    String error,
    Emitter<OnboardingState> emit,
  ) async {
    debugPrint('Error: $error');
    emit(
      state.copyWith(
        onboardingStepStatus: OnboardingStepStatus.error(error),
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
          onboardingStepStatus: const OnboardingStepStatus.loading(),
          step: OnboardingStep.create,
        ),
      );
      await _createDefaultWalletsUsecase.execute();
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.success(),
        ),
      );
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

    hintWords[wordIndex] = await _findMnemonicWordsUsecase.execute(word);

    if (hintWords[wordIndex]?.contains(word) == true) {
      validWords[event.index] = event.word;
    } else {
      validWords.remove(event.index);
    }

    emit(
      state.copyWith(
        validWords: validWords,
        hintWords: hintWords,
      ),
    );
  }

  Future<void> _onRecoverWalletClicked(
    OnboardingRecoverWalletClicked event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.loading(),
          step: OnboardingStep.recover,
        ),
      );
      emit(
        state.copyWith(
          hintWords: {},
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: state.validWords.values.toList(),
      );

      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.success(),
        ),
      );
    } catch (e) {
      await _handleError(e.toString(), emit);
    }
  }

  Future<void> _fetchBackup(Emitter<OnboardingState> emit) async {
    try {
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.loading(),
        ),
      );

      final encryptedBackup = await state.vaultProvider.map(
        fileSystem: (provider) =>
            _fetchBackupFromFileSystemUsecase.execute(provider.fileAsString),
        googleDrive: (_) => _fetchLatestGoogleDriveBackupUsecase.execute(),
        iCloud: (_) => Future.error('iCloud backup not implemented'),
      );
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.success(),
          backupInfo: BackupInfo(backupFile: encryptedBackup as String),
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
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.loading(),
        ),
      );
      await _restoreEncryptedVaultFromBackupKeyUsecase.execute(
        backupFile: event.backupFile,
        backupKey: event.backupKey,
      );
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.success(),
        ),
      );
      return;
    } catch (e) {
      await _handleError(
        'Failed recover the wallet: ${BackupInfo(backupFile: event.backupFile).id}',
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
          onboardingStepStatus: const OnboardingStepStatus.loading(),
        ),
      );

      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        throw Exception('No file selected');
      }

      emit(
        state.copyWith(
          vaultProvider: VaultProvider.fileSystem(selectedFile),
        ),
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
      emit(
        state.copyWith(
          onboardingStepStatus: const OnboardingStepStatus.loading(),
        ),
      );

      await _connectToGoogleDriveUsecase.execute();
      emit(
        state.copyWith(
          vaultProvider: const VaultProvider.googleDrive(),
        ),
      );
      await _fetchBackup(emit);
    } catch (e) {
      await _handleError('Failed to fetch backup: $e', emit);
    }
  }
}
