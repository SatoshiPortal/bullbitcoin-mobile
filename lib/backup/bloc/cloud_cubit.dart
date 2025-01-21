import 'dart:io' as io;

import 'package:bb_mobile/_pkg/backup/google_drive.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CloudCubit extends Cubit<CloudState> {
  final GoogleDriveBackupManager manager;
  CloudCubit({required this.manager}) : super(const CloudState());

  void clearToast() => emit(state.copyWith(toast: '', loading: false));

  void clearError() => emit(state.copyWith(error: '', loading: false));

  Future<void> connect() async {
    try {
      emit(state.copyWith(loading: true));
      final (folderId, err) = await manager.connect();

      if (folderId != null) {
        emit(
          state.copyWith(
            backupFolderId: folderId,
            loading: false,
          ),
        );
      } else if (err != null) {
        emit(
          state.copyWith(
            error: err.message,
            loading: false,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          error: "GoogleDrive Error: $e",
          loading: false,
        ),
      );
    }
  }

  Future<void> uploadBackup({
    required String fileSystemBackupPath,
  }) async {
    if (state.loading) {
      emit(state.copyWith(error: 'Backup already in progress'));
      return;
    }
    final now = DateTime.now();
    if (state.lastBackupAttempt != null) {
      final difference = now.difference(state.lastBackupAttempt!);
      if (difference.inSeconds < 30) {
        emit(
          state.copyWith(
            error:
                'Please wait ${30 - difference.inSeconds} seconds before creating another backup',
          ),
        );
        return;
      }
    }
    if (state.backupFolderId.isEmpty) await connect();
    emit(state.copyWith(loading: true, lastBackupAttempt: now));

    try {
      final backup = io.File(fileSystemBackupPath);
      final content = await backup.readAsString();
      final (fileName, err) = await manager.saveEncryptedBackup(
        encrypted: content,
        backupFolder: state.backupFolderId,
      );

      if (err != null) {
        debugPrint("Failed to backup file to Google Drive: ${err.message}");
        emit(
          state.copyWith(
            error: "Failed to backup file to Google Drive",
            loading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            toast: "Successfully backed up to Google Drive",
            loading: false,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          error: "Failed to backup file: $e",
          loading: false,
        ),
      );
    }
  }

  void disconnect() {
    manager.disconnect();
    emit(state.copyWith(backupFolderId: '', loading: false));
  }
}
