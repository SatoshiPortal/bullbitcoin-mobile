import 'dart:convert';
import 'dart:io' as io;
import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:hex/hex.dart';

class CloudCubit extends Cubit<CloudState> {
  CloudCubit() : super(const CloudState());

  void clearToast() => emit(state.copyWith(toast: '', loading: false));

  void clearError() => emit(state.copyWith(error: '', loading: false));

  Future<void> driveConnect() async {
    try {
      emit(state.copyWith(loading: true));
      final (googleDriveApi, err) = await GoogleDriveApi.connect();

      if (googleDriveApi != null) {
        emit(
          state.copyWith(
            googleDriveApi: googleDriveApi,
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

  Future<void> uploadBackup(String backupPath, String backupName) async {
    if (state.googleDriveApi == null) await driveConnect();
    final backup = io.File(backupPath);

    final content = await backup.readAsString();

    final decoded = HEX.decode(content);
    final (isCreated, err) =
        await state.googleDriveApi?.saveBackup(decoded, backupName) ??
            (false, 'Google Drive API is not available.');
    if (isCreated == false) {
      emit(
        state.copyWith(
          error: "Failed to backup file to Google Drive: $err",
          loading: false,
        ),
      );
    } else {
      emit(
        state.copyWith(
          toast: "Google Drive backup successful",
          loading: false,
        ),
      );
    }
  }

  Future<void> readAllBackups() async {
    try {
      emit(state.copyWith(loading: true));
      final api = state.googleDriveApi;
      if (api == null) {
        await driveConnect();
      }

      if (api == null) {
        emit(
          state.copyWith(
            loading: false,
            error: "Google Drive API is not available.",
          ),
        );
        return;
      }

      final (availableBackups, err) = await api.listAllBackupFiles();
      if (err != null) {
        emit(
          state.copyWith(
            loading: false,
            error: "Failed to list backup files: ${err.message}",
          ),
        );
        return;
      }

      if (availableBackups.isNotEmpty) {
        emit(
          state.copyWith(loading: false, availableBackups: availableBackups),
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

  Future<void> readCloudBackup(File file) async {
    try {
      if (state.googleDriveApi == null) await driveConnect();
      emit(state.copyWith(loading: true));

      final (metaData, err) =
          await state.googleDriveApi!.loadBackupContent(file);
      if (err != null) {
        emit(
          state.copyWith(
            loading: false,
            error: "Failed to read backup: ${err.message}",
          ),
        );
        return;
      }

      final decodeEncryptedFile = utf8.decode(metaData!);
      final id = jsonDecode(decodeEncryptedFile)['backupId']?.toString() ?? '';
      if (decodeEncryptedFile.isEmpty || id.isEmpty) {
        emit(state.copyWith(loading: false, error: 'Invalid backup data'));
        return;
      }

      emit(
        state.copyWith(
          loading: false,
          selectedBackup: (id, decodeEncryptedFile),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: "Failed to read backup: $e",
        ),
      );
    }
  }

  void disconnect() => GoogleDriveApi.disconnect();
}
