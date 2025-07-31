import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/complete_physical_backup_verification_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/complete_encrypted_vault_verification_usecase.dart.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/load_wallets_for_network_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_wallet_backup_bloc.freezed.dart';
part 'test_wallet_backup_event.dart';
part 'test_wallet_backup_state.dart';

class TestWalletBackupBloc
    extends Bloc<TestWalletBackupEvent, TestWalletBackupState> {
  TestWalletBackupBloc({
    required SelectFileFromPathUsecase selectFileFromPathUsecase,
    required ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase,
    required RestoreEncryptedVaultFromBackupKeyUsecase
    restoreEncryptedVaultFromBackupKeyUsecase,
    required FetchLatestGoogleDriveBackupUsecase
    fetchLatestGoogleDriveBackupUsecase,
    required FetchBackupFromFileSystemUsecase fetchBackupFromFileSystemUsecase,
    required CompleteEncryptedVaultVerificationUsecase
    completeEncryptedVaultVerificationUsecase,
    required CompletePhysicalBackupVerificationUsecase
    completePhysicalBackupVerificationUsecase,
    required LoadWalletsForNetworkUsecase loadWalletsForNetworkUsecase,
    required GetMnemonicFromFingerprintUsecase
    getMnemonicFromFingerprintUsecase,
  }) : _selectFileFromPathUsecase = selectFileFromPathUsecase,
       _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
       _restoreEncryptedVaultFromBackupKeyUsecase =
           restoreEncryptedVaultFromBackupKeyUsecase,
       _fetchLatestGoogleDriveBackupUsecase =
           fetchLatestGoogleDriveBackupUsecase,
       _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
       _completeEncryptedVaultVerificationUsecase =
           completeEncryptedVaultVerificationUsecase,
       _completePhysicalBackupVerificationUsecase =
           completePhysicalBackupVerificationUsecase,
       _loadWalletsForNetworkUsecase = loadWalletsForNetworkUsecase,
       _getMnemonicFromFingerprintUsecase = getMnemonicFromFingerprintUsecase,
       super(const TestWalletBackupState()) {
    on<SelectGoogleDriveBackupTest>(_onSelectGoogleDriveBackupTest);
    on<SelectFileSystemBackupTes>(_onSelectFileSystemBackupTest);
    on<StartVaultBackupTesting>(_onStartVaultBackupTesting);
    on<OnWordsSelected>(_onWordsSelected);
    on<VerifyPhysicalBackup>(_verifyPhysicalBackup);
    on<StartPhysicalBackupVerification>((event, emit) {
      emit(state.copyWith(status: TestWalletBackupStatus.verifying));
    });
    on<LoadWallets>(_onLoadWallets);
    on<LoadMnemonicForWallet>(_onLoadMnemonicForWallet);
    on<StartTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: true));
    });
    on<EndTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: false));
    });
  }

  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
  _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchLatestGoogleDriveBackupUsecase
  _fetchLatestGoogleDriveBackupUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;
  final CompleteEncryptedVaultVerificationUsecase
  _completeEncryptedVaultVerificationUsecase;
  final CompletePhysicalBackupVerificationUsecase
  _completePhysicalBackupVerificationUsecase;
  final LoadWalletsForNetworkUsecase _loadWalletsForNetworkUsecase;
  final GetMnemonicFromFingerprintUsecase _getMnemonicFromFingerprintUsecase;

  Future<void> _onSelectGoogleDriveBackupTest(
    SelectGoogleDriveBackupTest event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(status: TestWalletBackupStatus.loading));

      await _connectToGoogleDriveUsecase.execute();
      emit(state.copyWith(vaultProvider: const VaultProvider.googleDrive()));

      final (content: encryptedBackup, fileName: _) =
          await _fetchLatestGoogleDriveBackupUsecase.execute();

      emit(
        state.copyWith(
          status: TestWalletBackupStatus.success,
          backupInfo: encryptedBackup.backupInfo,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to fetch backup: $e',
        ),
      );
    }
  }

  Future<void> _onSelectFileSystemBackupTest(
    SelectFileSystemBackupTes event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.loading,
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

      final encryptedBackup = await _fetchBackupFromFileSystemUsecase.execute(
        selectedFile,
      );
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.success,
          backupInfo: encryptedBackup.backupInfo,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to fetch backup: $e',
        ),
      );
    }
  }

  Future<void> _onStartVaultBackupTesting(
    StartVaultBackupTesting event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(status: TestWalletBackupStatus.loading));

      try {
        await _restoreEncryptedVaultFromBackupKeyUsecase.execute(
          backupFile: event.backupFile,
          backupKey: event.backupKey,
        );
        // If we get here, something went wrong because we expect DefaultWalletAlreadyExistsError
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError:
                'Unexpected success: backup should match existing wallet',
          ),
        );
      } catch (e) {
        if (e is TestFlowDefaultWalletAlreadyExistsError) {
          try {
            await _completeEncryptedVaultVerificationUsecase.execute();
            emit(state.copyWith(status: TestWalletBackupStatus.success));
          } catch (e) {
            emit(
              state.copyWith(
                status: TestWalletBackupStatus.error,
                statusError: 'Write to storage failed: $e',
              ),
            );
          }
        } else if (e is TestFlowWalletMismatchError) {
          emit(
            state.copyWith(
              status: TestWalletBackupStatus.error,
              statusError: 'Backup does not match existing wallet',
            ),
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError:
              'Failed to test backup: ${event.backupFile.backupInfo.id}',
        ),
      );
    }
  }

  /// Handles word selection during backup verification
  /// Validates word order and updates test state
  Future<void> _onWordsSelected(
    OnWordsSelected event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    final testMnemonic = state.testMnemonicOrder.toList();
    if (testMnemonic.length == 12) return;

    final (word, isSelected, actualIdx) = state.shuffleElementAt(
      event.shuffledIdx,
    );
    if (isSelected) return;
    if (actualIdx != testMnemonic.length) {
      await Future.delayed(const Duration(milliseconds: 300));
      final shuffled = state.mnemonic.toList()..shuffle();
      emit(
        state.copyWith(
          shuffledMnemonic: shuffled,
          testMnemonicOrder: [], // Reset selection when order is wrong
        ),
      );
      return;
    }

    // Add the selected word to testMnemonicOrder
    testMnemonic.add((
      word: word,
      shuffleIdx: event.shuffledIdx,
      selectedActualIdx: actualIdx,
    ));

    // Emit new state with updated testMnemonicOrder
    emit(state.copyWith(testMnemonicOrder: testMnemonic, statusError: ''));
  }

  Future<void> _verifyPhysicalBackup(
    VerifyPhysicalBackup event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      if (state.mnemonic.isEmpty) {
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'No mnemonic loaded',
          ),
        );
        return;
      }

      if (state.testMnemonicOrder.length != state.mnemonic.length) {
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'Please select all words',
          ),
        );
        return;
      }

      // Get the words in order from testMnemonicOrder
      final submittedWords =
          state.testMnemonicOrder.map((e) => e.word).toList();

      // Compare with original mnemonic
      final isCorrect = List.generate(
        state.mnemonic.length,
        (i) => state.mnemonic[i] == submittedWords[i],
      ).every((matched) => matched);

      if (isCorrect) {
        await _completePhysicalBackupVerificationUsecase.execute();
        emit(state.copyWith(status: TestWalletBackupStatus.success));
      } else {
        // Reset test state when wrong
        final shuffled = state.mnemonic.toList()..shuffle();
        emit(
          state.copyWith(
            status: TestWalletBackupStatus.error,
            statusError: 'Incorrect word order. Please try again.',
            shuffledMnemonic: shuffled,
            testMnemonicOrder: [],
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Verification failed: $e',
        ),
      );
    }
  }

  Future<void> _onLoadWallets(
    LoadWallets event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    emit(state.copyWith(status: TestWalletBackupStatus.loading));
    try {
      final wallets = await _loadWalletsForNetworkUsecase.execute();
      if (wallets.isEmpty) throw Exception('No wallets found');
      final Wallet selected = wallets.firstWhere(
        (w) => w.isDefault,
        orElse: () => wallets.first,
      );
      emit(state.copyWith(wallets: wallets, selectedWallet: selected));

      // Small delay to allow smooth UI transition before loading mnemonic
      Future.delayed(const Duration(milliseconds: 500), () {
        add(LoadMnemonicForWallet(wallet: selected));
      });
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to load wallets: $e',
        ),
      );
    }
  }

  Future<void> _onLoadMnemonicForWallet(
    LoadMnemonicForWallet event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      final wallet = event.wallet;
      final (
        mnemonicWords,
        passphrase,
      ) = await _getMnemonicFromFingerprintUsecase.execute(
        wallet.masterFingerprint,
      );

      emit(
        state.copyWith(
          selectedWallet: wallet,
          mnemonic: mnemonicWords,
          passphrase: passphrase ?? '',
          shuffledMnemonic: mnemonicWords.toList()..shuffle(),
          testMnemonicOrder: [],
          status: TestWalletBackupStatus.success,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.error,
          statusError: 'Failed to load mnemonic: $e',
        ),
      );
    }
  }
}
