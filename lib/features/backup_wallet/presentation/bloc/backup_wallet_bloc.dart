import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/backup_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'backup_wallet_bloc.freezed.dart';
part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedVaultUsecase createEncryptedBackupUsecase;
  final SelectFolderPathUsecase selectFolderPathUsecase;
  final ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase;
  final FetchLatestGoogleDriveBackupUsecase fetchLatestBackupUsecase;
  final DisconnectFromGoogleDriveUsecase disconnectFromGoogleDriveUsecase;
  final SaveToFileSystemUsecase saveToFileSystemUsecase;
  final SaveToGoogleDriveUsecase saveToGoogleDriveUsecase;
  BackupWalletBloc({
    required this.createEncryptedBackupUsecase,
    required this.fetchLatestBackupUsecase,
    required this.connectToGoogleDriveUsecase,
    required this.disconnectFromGoogleDriveUsecase,
    required this.selectFolderPathUsecase,
    required this.saveToFileSystemUsecase,
    required this.saveToGoogleDriveUsecase,
  }) : super(const BackupWalletState()) {
    on<OnFileSystemBackupSelected>(_onFileSystemBackupSelected);
    on<OnGoogleDriveBackupSelected>(_onGoogleDriveBackupSelected);
    on<OnICloudDriveBackupSelected>(_onICloudDriveBackupSelected);
    on<StartWalletBackup>(_onStartWalletBackup);

    // Add handlers for transitioning events
    on<StartTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: true));
    });

    on<EndTransitioning>((event, emit) {
      emit(state.copyWith(transitioning: false));
    });
  }

  Future<void> _onFileSystemBackupSelected(
    OnFileSystemBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: BackupWalletStatus.loading,
          vaultProvider: const VaultProvider.fileSystem(''),
        ),
      );
      final filePath = await selectFolderPathUsecase.execute();
      if (filePath == null) {
        emit(state.copyWith(status: BackupWalletStatus.none));
        return;
      }

      // First update the state with the selected provider
      emit(
        state.copyWith(
          vaultProvider: VaultProvider.fileSystem(filePath),
          status: BackupWalletStatus.success,
        ),
      );

      // Then start the backup process
      await _startBackup(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: BackupWalletStatus.error,
          statusError: 'Failed to select file system path',
        ),
      );
    }
  }

  Future<void> _onGoogleDriveBackupSelected(
    OnGoogleDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(state.copyWith(status: BackupWalletStatus.loading));

      await Future.delayed(const Duration(seconds: 2));
      await connectToGoogleDriveUsecase.execute();

      // First update the state with the selected provider
      emit(
        state.copyWith(
          vaultProvider: const VaultProvider.googleDrive(),
          status: BackupWalletStatus.success,
        ),
      );

      // Then start the backup process
      await _startBackup(emit);
    } catch (e) {
      log.severe('Error connecting to Google Drive: $e');
      emit(
        state.copyWith(
          status: BackupWalletStatus.error,
          statusError: 'Failed to connect to Google Drive',
        ),
      );
    }
  }

  Future<void> _startBackup(Emitter<BackupWalletState> emit) async {
    try {
      emit(state.copyWith(status: BackupWalletStatus.loading));

      final encryptedBackup = await createEncryptedBackupUsecase.execute();

      emit(state.copyWith(backupFile: encryptedBackup));

      switch (state.vaultProvider) {
        case FileSystem(:final fileAsString):
          if (fileAsString.isEmpty) throw Exception('No file path selected');
          await saveToFileSystemUsecase.execute(fileAsString, encryptedBackup);
        case GoogleDrive():
          await saveToGoogleDriveUsecase.execute(encryptedBackup);
        case ICloud():
          throw UnimplementedError('iCloud backup not implemented');
      }

      emit(state.copyWith(status: BackupWalletStatus.success));
    } catch (e) {
      log.severe('Failed to save the backup: $e');
      emit(
        state.copyWith(
          status: BackupWalletStatus.error,
          statusError: 'Failed to save the backup',
        ),
      );
    }
  }

  Future<void> _onStartWalletBackup(
    StartWalletBackup event,
    Emitter<BackupWalletState> emit,
  ) async {
    await _startBackup(emit);
  }

  Future<void> _onICloudDriveBackupSelected(
    OnICloudDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    log.severe('iCloud backup not implemented');
    return;
  }
}
