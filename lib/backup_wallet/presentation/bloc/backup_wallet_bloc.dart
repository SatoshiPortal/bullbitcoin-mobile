import 'dart:async';

import 'package:bb_mobile/_core/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/disconnect_google_drive_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/google_drive/fetch_latest_backup_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_default_wallet_use_case.dart';
import 'package:bb_mobile/_core/domain/usecases/pick_file_use_case.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/create_encrypted_backup_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_key_to_server_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_file_system_usecase.dart';
import 'package:bb_mobile/backup_wallet/domain/usecases/save_to_google_drive_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_wallet_bloc.freezed.dart';
part 'backup_wallet_event.dart';
part 'backup_wallet_state.dart';

class BackupWalletBloc extends Bloc<BackupWalletEvent, BackupWalletState> {
  final CreateEncryptedBackupUsecase createEncryptedBackupUsecase;
  final GetDefaultWalletUseCase getDefaultWalletUseCase;
  final SelectFilePathUseCase _selectFilePathUseCase;
  final ConnectToGoogleDriveUseCase connectToGoogleDriveUseCase;
  final FetchLatestBackupUsecase fetchLatestBackupUsecase;
  final DisconnectFromGoogleDriveUseCase disconnectFromGoogleDriveUseCase;
  final SaveToFileSystemUseCase _saveToFileSystemUseCase;
  final SaveToGoogleDriveUseCase _saveToGoogleDriveUseCase;
  final SaveBackupKeyToServerUsecase saveBackupKeyToServerUsecase;
  BackupWalletBloc({
    required this.createEncryptedBackupUsecase,
    required this.getDefaultWalletUseCase,
    required this.saveBackupKeyToServerUsecase,
    required this.fetchLatestBackupUsecase,
    required this.connectToGoogleDriveUseCase,
    required this.disconnectFromGoogleDriveUseCase,
    required SelectFilePathUseCase selectFilePathUseCase,
    required SaveToFileSystemUseCase saveToFileSystemUseCase,
    required SaveToGoogleDriveUseCase saveToGoogleDriveUseCase,
  })  : _selectFilePathUseCase = selectFilePathUseCase,
        _saveToFileSystemUseCase = saveToFileSystemUseCase,
        _saveToGoogleDriveUseCase = saveToGoogleDriveUseCase,
        super(BackupWalletState()) {
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
      emit(state.copyWith(status: const BackupWalletStatus.loading()));
      final filePath = await _selectFilePathUseCase.execute();
      if (filePath == null) {
        emit(state.copyWith(status: const BackupWalletStatus.loading()));
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
      await connectToGoogleDriveUseCase.execute();
      emit(
        state.copyWith(
          status: const BackupWalletStatus.success(),
          backupProvider: const BackupProvider.googleDrive(),
        ),
      );
      return;
    } catch (e) {
      debugPrint("Failed to connect to Google Drive $e");
      emit(BackupWalletState.error("Failed to connect to Google Drive"));
      return;
    }
  }

  Future<void> _onStartWalletBackup(
    StartWalletBackup event,
    Emitter<BackupWalletState> emit,
  ) async {
    try {
      emit(state.copyWith(status: const BackupWalletStatus.loading()));
      // final encrytedBackup = await createEncryptedBackupUsecase.execute();
      // if (state.filePath.isEmpty) {
      //   debugPrint('No file path selected');
      //   emit(state.copyWith(status: const BackupWalletStatus.success()));
      //   return;
      // }
      // await _saveToFileSystemUseCase.execute(state.filePath, encrytedBackup);
      // emit(state.copyWith(status: const BackupWalletStatus.success()));
      return;
    } catch (e) {
      emit(BackupWalletState.error("Failed to backup wallet"));
    }
  }

  Future<void> _onICloudDriveBackupSelected(
    OnICloudDriveBackupSelected event,
    Emitter<BackupWalletState> emit,
  ) async {
    return;
  }
}
