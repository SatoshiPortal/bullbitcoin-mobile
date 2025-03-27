import 'dart:async';

import 'package:bb_mobile/core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/domain/usecases/select_folder_path_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
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

      // First update the state with the selected provider
      emit(
        state.copyWith(
          backupProvider: BackupProvider.fileSystem(filePath),
          status: const BackupWalletStatus.success(),
        ),
      );

      // Then start the backup process
      await _startBackup(emit);
    } catch (e) {
      emit(
        state.copyWith(
          status: const BackupWalletStatus.failure(
            'Failed to select file system path',
          ),
        ),
      );
    }
  }

  Future<void> _onGoogleDriveBackupSelected(
    OnGoogleDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: const BackupWalletStatus.loading(LoadingType.googleSignIn),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));
      await connectToGoogleDriveUsecase.execute();

      // First update the state with the selected provider
      emit(
        state.copyWith(
          backupProvider: const BackupProvider.googleDrive(),
          status: const BackupWalletStatus.success(),
        ),
      );

      // Then start the backup process
      await _startBackup(emit);
    } catch (e) {
      debugPrint('Error connecting to Google Drive: $e');
      emit(
        state.copyWith(
          status: const BackupWalletStatus.failure(
            'Failed to connect to Google Drive',
          ),
        ),
      );
    }
  }

  Future<void> _startBackup(Emitter<BackupWalletState> emit) async {
    try {
      emit(
        state.copyWith(
          status: const BackupWalletStatus.loading(LoadingType.general),
        ),
      );

      final encryptedBackup = await createEncryptedBackupUsecase.execute();

      emit(state.copyWith(backupFile: encryptedBackup));

      await state.backupProvider.when(
        fileSystem: (filePath) async {
          if (filePath.isEmpty) throw Exception('No file path selected');
          await saveToFileSystemUsecase.execute(filePath, encryptedBackup);
        },
        googleDrive: () async {
          await saveToGoogleDriveUsecase.execute(encryptedBackup);
        },
        iCloud: () => throw UnimplementedError('iCloud backup not implemented'),
      );

      emit(state.copyWith(status: const BackupWalletStatus.success()));
    } catch (e) {
      debugPrint('Failed to save the backup: $e');
      emit(
        state.copyWith(
          status: const BackupWalletStatus.failure('Failed to save the backup'),
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
    debugPrint('iCloud backup not implemented');
    return;
  }
}
