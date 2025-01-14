import 'dart:convert';
import 'dart:io' as io;

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

//TODO; Move this google drive cubit and share it with recover and backup cubit
class CloudCubit extends Cubit<CloudState> {
  CloudCubit() : super(const CloudState());

  void clearToast() => emit(state.copyWith(toast: '', loading: false));

  void clearError() => emit(state.copyWith(error: '', loading: false));
  //move to a google drive repository
  Future<void> driveConnect() async {
    try {
      emit(state.copyWith(loading: true));
      final googleSignInAccount = await GoogleDriveApi.google.signIn();
      final googleDriveStorage = await GoogleDriveStorage.connect(
        googleSignInAccount,
        defaultBackupPath,
      );
      if (googleSignInAccount != null) {
        emit(
          state.copyWith(
            googleDriveStorage: googleDriveStorage,
            loading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            error: "Google drive user has not authenticated",
            loading: false,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint("GoogleDriveStorage.connect Error: $e");
      emit(
        state.copyWith(
          error: "GoogleDriveStorage.connect Error: $e",
          loading: false,
        ),
      );
      return;
    }
  }

  Future<void> uploadBackup(String backupPath, String backupName) async {
    if (state.googleDriveStorage == null) await driveConnect();
    final backup = io.File(backupPath);

    final content = await backup.readAsString();

    final decoded = HEX.decode(content);
    final isCreated =
        await state.googleDriveStorage?.writeMetaData(decoded, backupName);
    if (isCreated == false) {
      emit(
        state.copyWith(
          error: "Failed to backup file to google drive.",
          loading: false,
        ),
      );
      return;
    } else {
      emit(
        state.copyWith(
          toast: "Google drive backup successful",
          loading: false,
        ),
      );
      return;
    }
  }

  Future<void> readAllBackups() async {
    try {
      if (state.googleDriveStorage == null) driveConnect();
      emit(state.copyWith(loading: true));
      final availableBackups =
          await state.googleDriveStorage?.readAllMetaDataFiles();
      if (availableBackups != null) {
        emit(
          state.copyWith(
            loading: false,
            toast: "Found ${availableBackups.length} backups files",
            availableBackups: availableBackups,
          ),
        );
      } else {
        emit(
          state.copyWith(
            loading: false,
            error: "No backup files found",
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: "Failed to read all backups: $e",
        ),
      );
    }
  }

  Future<void> readCloudBackup(File file) async {
    try {
      if (state.googleDriveStorage == null) driveConnect();
      emit(
        state.copyWith(
          loading: true,
        ),
      );
      final metaData =
          await state.googleDriveStorage!.readMetaDataContent(file);
      final decodeEncryptedFile = utf8.decode(metaData);
      final id = jsonDecode(decodeEncryptedFile)['backupId']?.toString() ?? '';
      if (decodeEncryptedFile.isEmpty || id.isEmpty) {
        emit(state.copyWith(error: 'Invalid backup data'));
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
