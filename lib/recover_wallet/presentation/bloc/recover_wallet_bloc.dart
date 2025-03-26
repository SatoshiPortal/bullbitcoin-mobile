import 'dart:async';

import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/find_mnemonic_words_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/onboarding/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/recover_wallet_use_case.dart';
import 'package:bb_mobile/recover_wallet/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recover_wallet_bloc.freezed.dart';
part 'recover_wallet_event.dart';
part 'recover_wallet_state.dart';

class RecoverWalletBloc extends Bloc<RecoverWalletEvent, RecoverWalletState> {
  RecoverWalletBloc({
    required SelectFileFromPathUsecase selectFilePathUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required RecoverOrCreateWalletUsecase recoverOrCreateWalletUsecase,
    required FindMnemonicWordsUsecase findMnemonicWordsUsecase,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
    required RestoreEncryptedVaultFromBackupKeyUsecase
        restoreEncryptedVaultFromBackupKeyUsecase,
    required FetchLatestGoogleDriveBackupUsecase
        fetchLatestGoogleDriveBackupUsecase,
    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,
    bool useTestWallet = false,
  })  : _recoverOrCreateWalletUsecase = recoverOrCreateWalletUsecase,
        _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
        _selectFileFromPathUsecase = selectFilePathUsecase,
        _findMnemonicWordsUsecase = findMnemonicWordsUsecase,
        _createDefaultWalletsUsecase = createDefaultWalletsUsecase,
        _restoreEncryptedVaultFromBackupKeyUsecase =
            restoreEncryptedVaultFromBackupKeyUsecase,
        _fetchLatestGoogleDriveBackupUsecase =
            fetchLatestGoogleDriveBackupUsecase,
        _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
        super(const RecoverWalletState()) {
    on<RecoverWalletWordsCountChanged>(_onWordsCountChanged);
    on<RecoverWalletWordChanged>(_onWordChanged);
    on<RecoverWalletPassphraseChanged>(_onPassphraseChanged);
    on<RecoverWalletLabelChanged>(_onLabelChanged);
    // on<RecoverWalletConfirmed>(_onConfirmed);
    on<RecoverFromOnboarding>(_onRecoverFromOnboarding);
    on<ImportTestableWallet>(_importTestableWallet);
    on<ClearUntappedWords>(_clearUntappedWords);
    on<SelectGoogleDriveRecovery>(_onGoogleDriveRecoverSelected);
    on<SelectFileSystemRecovery>(_onFileSystemRecoverSelected);
    on<DecryptRecoveryFile>(_onDecryptRecoveryFile);
    if (!kReleaseMode) {
      add(ImportTestableWallet(useTestWallet: useTestWallet));
    }
  }

  final FindMnemonicWordsUsecase _findMnemonicWordsUsecase;

  final CreateDefaultWalletsUsecase _createDefaultWalletsUsecase;
  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RecoverOrCreateWalletUsecase _recoverOrCreateWalletUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
      _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchLatestGoogleDriveBackupUsecase
      _fetchLatestGoogleDriveBackupUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;

  void _importTestableWallet(
    ImportTestableWallet event,
    Emitter<RecoverWalletState> emit,
  ) {
    if (event.useTestWallet) {
      final words = importWords(secureTN1);
      for (int i = 0; i < words.length; i++) {
        final word = words[i] ?? '';
        add(RecoverWalletWordChanged(index: i, word: word, tapped: true));
      }

      return;
    }
  }

  void _onRecoverFromOnboarding(
    RecoverFromOnboarding event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(fromOnboarding: true));
  }

  void _onWordsCountChanged(
    RecoverWalletWordsCountChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    final words = Map<int, String>.from(state.validWords);
    final hintWords = Map<int, List<String>>.from(state.hintWords);

    words.removeWhere((index, _) => index >= event.wordsCount);
    hintWords.removeWhere((index, _) => index >= event.wordsCount);
    emit(
      state.copyWith(
        wordsCount: event.wordsCount,
        validWords: words,
        hintWords: hintWords,
      ),
    );
  }

  Future<void> _onWordChanged(
    RecoverWalletWordChanged event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      final wordIndex = event.index;
      final word = event.word.trim().toLowerCase();
      final validWords = Map<int, String>.from(state.validWords);
      final hintWords = Map<int, List<String>>.from(state.hintWords);

      hintWords[wordIndex] = await _findMnemonicWordsUsecase.execute(word);

      if (hintWords[wordIndex]?.contains(word) == true) {
        validWords[wordIndex] = word;
      } else {
        validWords.remove(wordIndex);
      }

      emit(
        state.copyWith(
          validWords: validWords,
          hintWords: hintWords,
          recoverWalletStatus: const RecoverWalletStatus.initial(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus:
              RecoverWalletStatus.failure('Failed to validate word: $e'),
        ),
      );
    }
  }

  Future<void> _clearUntappedWords(
    ClearUntappedWords event,
    Emitter<RecoverWalletState> emit,
  ) async {}

  void _onPassphraseChanged(
    RecoverWalletPassphraseChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(passphrase: event.passphrase));
  }

  void _onLabelChanged(
    RecoverWalletLabelChanged event,
    Emitter<RecoverWalletState> emit,
  ) {
    emit(state.copyWith(label: event.label));
  }

  Future<void> _onConfirmed(
    RecoverWalletConfirmed event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );
      await _createDefaultWalletsUsecase.execute(
        mnemonicWords: state.validWords.values.toList(),
        passphrase: state.passphrase,
      );

      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.success(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus: RecoverWalletStatus.failure(e.toString()),
        ),
      );
    }
  }

  Future<void> _onGoogleDriveRecoverSelected(
    SelectGoogleDriveRecovery event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );
      await _connectToGoogleDriveUsecase.execute();

      // First update the state with the selected provider
      emit(
        state.copyWith(
          backupProvider: const RecoverProvider.googleDrive(),
        ),
      );
      await _fetchBackup(emit);
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus: RecoverWalletStatus.failure(
            'Failed to connect to Google Drive: $e',
          ),
        ),
      );
    }
  }

  Future<void> _onFileSystemRecoverSelected(
    SelectFileSystemRecovery event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );
      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        emit(
          state.copyWith(
            recoverWalletStatus: const RecoverWalletStatus.failure(
              "Failed to select file system path.",
            ),
          ),
        );
        return;
      }

      // First update the state with the selected provider
      emit(
        state.copyWith(
          backupProvider: RecoverProvider.fileSystem(selectedFile),
        ),
      );

      // Then start the recover process
      await _fetchBackup(emit);
    } catch (e) {
      debugPrint("FileSystemRecoverSelected error: $e");
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.failure(
            'Failed to select file system path',
          ),
        ),
      );
    }
  }

  Future<void> _fetchBackup(Emitter<RecoverWalletState> emit) async {
    try {
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );

      final encryptedBackup = await state.backupProvider.map(
        fileSystem: (provider) =>
            _fetchBackupFromFileSystemUsecase.execute(provider.fileAsString),
        googleDrive: (_) => _fetchLatestGoogleDriveBackupUsecase.execute(),
        iCloud: (_) => Future.error('iCloud backup not implemented'),
      );

      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.success(),
          encryptedInfo: BackupInfo(backupFile: encryptedBackup as String),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus:
              RecoverWalletStatus.failure('Failed to fetch backup: $e'),
        ),
      );
    }
  }

  Future<void> _onDecryptRecoveryFile(
    DecryptRecoveryFile event,
    Emitter<RecoverWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.loading(),
        ),
      );
      await _restoreEncryptedVaultFromBackupKeyUsecase.execute(
        backupFile: event.backupFile,
        backupKey: event.backupKey,
      );
      emit(
        state.copyWith(
          recoverWalletStatus: const RecoverWalletStatus.success(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          recoverWalletStatus:
              RecoverWalletStatus.failure('Failed to decrypt backup: $e'),
        ),
      );
    }
  }
}
