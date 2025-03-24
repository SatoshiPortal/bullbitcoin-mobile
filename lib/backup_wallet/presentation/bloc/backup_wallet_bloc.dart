import 'dart:async';

import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/select_file_path_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_wallet_bloc.freezed.dart';
part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedVaultUsecase createEncryptedBackupUsecase;
  final SelectFolderPathUsecase selectFolderPathUsecase;
  final ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase;
  final FetchLatestBackupUsecase fetchLatestBackupUsecase;
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
  }) : super(BackupWalletState.initial()) {
    on<OnFileSystemBackupSelected>(_onFileSystemBackupSelected);
    on<OnGoogleDriveBackupSelected>(_onGoogleDriveBackupSelected);
    on<OnICloudDriveBackupSelected>(_onICloudDriveBackupSelected);
    on<StartWalletBackup>(_onStartWalletBackup);
  }

  Future<void> _onFileSystemBackupSelected(
    OnFileSystemBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: const BackupWalletStatus.loading(LoadingType.general),
        ),
      );
      final filePath = await selectFolderPathUsecase.execute();
      if (filePath == null) {
        emit(state.copyWith(status: const BackupWalletStatus.initial()));
        return;
      }
      emit(
        state.copyWith(
          backupProvider: BackupProvider.fileSystem(filePath),
          status: const BackupWalletStatus.success(),
        ),
      );
      return;
    } catch (e) {
      emit(BackupWalletState.error("Failed to select file system path"));
      return;
    }
  }

  Future<void> _onGoogleDriveBackupSelected(
    OnGoogleDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(state.copyWith(status: const BackupWalletStatus.loading()));
      await connectToGoogleDriveUsecase.execute();
      emit(
        state.copyWith(
          status: const BackupWalletStatus.success(),
          backupProvider: const BackupProvider.googleDrive(),
        ),
      );
      return;
    } catch (e) {
      debugPrint("Failed to connect to Google Drive: $e");
      emit(BackupWalletState.error("Failed to connect to Google Drive"));
    }
  }

  Future<void> _onStartWalletBackup(
    StartWalletBackup event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(state.copyWith(status: const BackupWalletStatus.loading()));

      // Create encrypted backup
      final encryptedBackup = await createEncryptedBackupUsecase.execute();

      // Store backup based on selected provider
      state.backupProvider.maybeWhen(
        fileSystem: (filePath) async {
          if (filePath.isEmpty) {
            throw Exception('No file path selected');
          }
          await saveToFileSystemUsecase.execute(filePath, encryptedBackup);
        },
        googleDrive: () async {
          await saveToGoogleDriveUsecase.execute(encryptedBackup);
        },
        iCloud: () => debugPrint('iCloud backup not implemented'),
        orElse: () => debugPrint('iCloud backup not implemented'),
      );
      debugPrint('Backup completed successfully to ${state.backupProvider}');
      emit(
        state.copyWith(
          status: const BackupWalletStatus.success(),
        ),
      );
    } catch (e) {
      debugPrint('Backup failed: $e');
      emit(BackupWalletState.error("Failed to backup wallet"));
    }
  }

  Future<void> _onICloudDriveBackupSelected(
    OnICloudDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    debugPrint('iCloud backup not implemented');
    return;
  }
}
