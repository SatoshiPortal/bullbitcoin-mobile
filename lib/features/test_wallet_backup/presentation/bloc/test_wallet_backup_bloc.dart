import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
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

    // Add handlers for transitioning events
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
  final UpdateEncryptedVaultTest _updateEncryptedVaultTest;
  Future<void> _onSelectGoogleDriveBackupTest(
    SelectGoogleDriveBackupTest event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.loading,
        ),
      );

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
          status: TestWalletBackupStatus.success,
          backupInfo: BackupInfo(backupFile: encryptedBackup),
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
        state.copyWith(
          vaultProvider: VaultProvider.fileSystem(selectedFile),
        ),
      );

      final encryptedBackup =
          await _fetchBackupFromFileSystemUsecase.execute(selectedFile);
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.success,
          backupInfo: BackupInfo(backupFile: encryptedBackup),
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

  Future<void> _onStartBackupTesting(
    StartBackupTesting event,
    Emitter<TestWalletBackupState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: TestWalletBackupStatus.loading,
        ),
      );

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
        if (e is DefaultWalletAlreadyExistsError) {
          try {
            await _updateEncryptedVaultTest.execute();
            emit(state.copyWith(status: TestWalletBackupStatus.success));
          } catch (e) {
            emit(
              state.copyWith(
                status: TestWalletBackupStatus.error,
                statusError: 'Write to storage failed: $e',
              ),
            );
          }
        } else if (e is WalletMismatchError) {
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
              'Failed to test backup: ${BackupInfo(backupFile: event.backupFile).id}',
        ),
      );
    }
  }
}
