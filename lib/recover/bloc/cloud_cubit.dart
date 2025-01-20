import 'dart:convert';

import 'package:bb_mobile/_pkg/backup/google_drive.dart';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:googleapis/drive/v3.dart';

part 'cloud_cubit.freezed.dart';
part 'cloud_state.dart';

class CloudCubit extends Cubit<CloudState> {
  final GoogleDriveBackupManager manager;
  CloudCubit({required this.manager}) : super(CloudState());

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

  Future<void> readAllBackups({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh &&
          state.availableBackups.isNotEmpty &&
          state.isCacheValid) {
        emit(state.copyWith(loading: false));
        return;
      }
      if (state.backupFolderId.isEmpty) {
        await connect();
      }
      emit(state.copyWith(loading: true));
      if (state.backupFolderId.isEmpty) {
        emit(
          state.copyWith(
            loading: false,
            error: "Google Drive connection failed.",
          ),
        );
        return;
      }
      final (availableBackups, err) = await manager.loadAllEncryptedBackupFiles(
        backupFolder: state.backupFolderId,
      );

      if (err != null) {
        emit(
          state.copyWith(
            loading: false,
            error: "Failed to list backup files: ${err.message}",
          ),
        );
        return;
      }

      if (availableBackups != null && availableBackups.isNotEmpty) {
        emit(
          state.copyWith(
            loading: false,
            availableBackups: availableBackups,
            lastFetchTime: DateTime.now(),
          ),
        );
      } else {
        emit(state.copyWith(loading: false, error: "No backup files found"));
      }
    } catch (e) {
      emit(
        state.copyWith(loading: false, error: "Failed to read all backups: $e"),
      );
    }
  }

  void setCacheValidityDuration(Duration duration) {
    emit(state.copyWith(cacheValidityDuration: duration));
  }

  Future<void> refreshBackups() => readAllBackups(forceRefresh: true);

  Future<void> loadEncrypted(String fileName) async {
    if (state.backupFolderId.isEmpty) await connect();
    emit(state.copyWith(loading: true));
    final metaData =
        await manager.fetchMediaStream(file: state.availableBackups[fileName]!);
    final (loadEncryptedBackup, err) = await manager.loadEncryptedBackup(
      encrypted: utf8.decode(metaData),
    );
    if (err != null) {
      emit(
        state.copyWith(
          loading: false,
          error: "Failed to read backup: ${err.message}",
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        toast: "Successfully loaded backup",
        selectedBackup: (
          loadEncryptedBackup?['backupId'] ?? '',
          jsonEncode(loadEncryptedBackup)
        ),
      ),
    );
  }

  void disconnect() {
    manager.disconnect();
    emit(state.copyWith(backupFolderId: ''));
  }
}
