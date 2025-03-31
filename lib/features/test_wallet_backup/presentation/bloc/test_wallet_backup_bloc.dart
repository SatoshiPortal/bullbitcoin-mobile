import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/errors/recover_wallet_error.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_backup_from_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_encrypted_vault_from_backup_key_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/update_encrypted_vault_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'test_wallet_backup_event.dart';
part 'test_wallet_backup_state.dart';
part 'test_wallet_backup_bloc.freezed.dart';

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
    required UpdateEncryptedVaultTest updateEncryptedVaultTest,
  })  : _selectFileFromPathUsecase = selectFileFromPathUsecase,
        _connectToGoogleDriveUsecase = connectToGoogleDriveUsecase,
        _restoreEncryptedVaultFromBackupKeyUsecase =
            restoreEncryptedVaultFromBackupKeyUsecase,
        _fetchLatestGoogleDriveBackupUsecase =
            fetchLatestGoogleDriveBackupUsecase,
        _fetchBackupFromFileSystemUsecase = fetchBackupFromFileSystemUsecase,
        _updateEncryptedVaultTest = updateEncryptedVaultTest,
        super(const TestWalletBackupState()) {
    on<SelectGoogleDriveBackupTest>(_onSelectGoogleDriveBackupTest);
    on<SelectFileSystemBackupTes>(_onSelectFileSystemBackupTest);
    on<StartBackupTesting>(_onStartBackupTesting);
  }

  final SelectFileFromPathUsecase _selectFileFromPathUsecase;
  final ConnectToGoogleDriveUsecase _connectToGoogleDriveUsecase;
  final RestoreEncryptedVaultFromBackupKeyUsecase
      _restoreEncryptedVaultFromBackupKeyUsecase;
  final FetchLatestGoogleDriveBackupUsecase
      _fetchLatestGoogleDriveBackupUsecase;
  final FetchBackupFromFileSystemUsecase _fetchBackupFromFileSystemUsecase;
  final UpdateEncryptedVaultTest _updateEncryptedVaultTest;
  Future<void> _onSelectGoogleDriveBackupTest(
    SelectGoogleDriveBackupTest event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: '', isSuccess: false));

      await _connectToGoogleDriveUsecase.execute();
      emit(
        state.copyWith(
          vaultProvider: const VaultProvider.googleDrive(),
        ),
      );

      final encryptedBackup =
          await _fetchLatestGoogleDriveBackupUsecase.execute();
      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          backupInfo: BackupInfo(backupFile: encryptedBackup),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to fetch backup: $e',
          isSuccess: false,
        ),
      );
    }
  }

  Future<void> _onSelectFileSystemBackupTest(
    SelectFileSystemBackupTes event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoading: true, error: '', isSuccess: false));

      final selectedFile = await _selectFileFromPathUsecase.execute();
      if (selectedFile == null) {
        throw Exception('No file selected');
      }

      emit(
        state.copyWith(
          vaultProvider: VaultProvider.fileSystem(selectedFile),
        ),
      );

      final encryptedBackup =
          await _fetchBackupFromFileSystemUsecase.execute(selectedFile);
      emit(
        state.copyWith(
          isLoading: false,
          isSuccess: true,
          backupInfo: BackupInfo(backupFile: encryptedBackup),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to fetch backup: $e',
          isSuccess: false,
        ),
      );
    }
  }

  Future<void> _onStartBackupTesting(
    StartBackupTesting event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      print('Testing backup: ${BackupInfo(backupFile: event.backupFile).id}');
      emit(state.copyWith(isLoading: true, error: '', isSuccess: false));

      try {
        await _restoreEncryptedVaultFromBackupKeyUsecase.execute(
          backupFile: event.backupFile,
          backupKey: event.backupKey,
        );
        // If we get here, something went wrong because we expect DefaultWalletAlreadyExistsError
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Unexpected success: backup should match existing wallet',
            isSuccess: false,
          ),
        );
      } catch (e) {
        if (e is DefaultWalletAlreadyExistsError) {
          try {
            await _updateEncryptedVaultTest.execute();
            emit(state.copyWith(isLoading: false, isSuccess: true));
          } catch (e) {
            emit(
              state.copyWith(
                isLoading: false,
                error: 'Failed to update vault: $e',
                isSuccess: false,
              ),
            );
          }
        } else if (e is WalletMismatchError) {
          emit(
            state.copyWith(
              isLoading: false,
              error: 'Backup does not match existing wallet',
              isSuccess: false,
            ),
          );
        } else {
          rethrow;
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error:
              'Failed to test backup: ${BackupInfo(backupFile: event.backupFile).id}',
          isSuccess: false,
        ),
      );
    }
  }
}
