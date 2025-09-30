import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
part 'backup_wallet_bloc.freezed.dart';
part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedVaultUsecase createEncryptedVaultUsecase;
  final ConnectToGoogleDriveUsecase connectToGoogleDriveUsecase;
  final FetchLatestGoogleDriveVaultUsecase fetchLatestBackupUsecase;
  final DisconnectFromGoogleDriveUsecase disconnectFromGoogleDriveUsecase;
  final SaveFileToSystemUsecase saveFileToSystemUsecase;
  final SaveToGoogleDriveUsecase saveToGoogleDriveUsecase;
  BackupWalletBloc({
    required this.createEncryptedVaultUsecase,
    required this.fetchLatestBackupUsecase,
    required this.connectToGoogleDriveUsecase,
    required this.disconnectFromGoogleDriveUsecase,
    required this.saveFileToSystemUsecase,
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
      // First update the state with the selected provider
      emit(
        state.copyWith(
          vaultProvider: VaultProvider.customLocation,
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
          vaultProvider: VaultProvider.googleDrive,
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
      final encryptedVault = await createEncryptedVaultUsecase.execute();

      switch (state.vaultProvider) {
        case VaultProvider.customLocation:
          await saveFileToSystemUsecase.execute(
            content: encryptedVault.toFile(),
            filename: EncryptedVault(file: encryptedVault.toFile()).filename,
          );
        case VaultProvider.googleDrive:
          await saveToGoogleDriveUsecase.execute(encryptedVault.toFile());
        case VaultProvider.iCloud:
          throw UnimplementedError('iCloud backup not implemented');
      }

      emit(
        state.copyWith(
          vault: encryptedVault,
          status: BackupWalletStatus.success,
        ),
      );
    } catch (e) {
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
