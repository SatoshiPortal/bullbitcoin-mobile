import 'dart:io';

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

class CloudCubit extends Cubit<CloudState> {
  final String backupPath;
  final String backupName;

  CloudCubit({
    required this.backupPath,
    required this.backupName,
  }) : super(const CloudState());

  void clearToast() => emit(state.copyWith(toast: ''));

  void clearError() => emit(state.copyWith(error: ''));
  Future<void> connectAndStoreBackup() async {
    try {
      emit(state.copyWith(loading: true));
      final googleSignInAccount = await GoogleDriveApi.google.signIn();
      final googleDriveStorage = await GoogleDriveStorage.connect(
        googleSignInAccount,
        defaultCloudBackupPath,
      );
      if (googleSignInAccount != null) {
        emit(state.copyWith(googleDriveStorage: googleDriveStorage));
      } else {
        emit(state.copyWith(error: "Google drive user has not authenticated"));
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

    final backup = File(backupPath);
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
    }
  }

  Future<void> readAllBackups() async {
    try {
      emit(
        state.copyWith(
          loading: true,
        ),
      );
      final availableBackups =
          await state.googleDriveStorage!.readAllMetaDataFiles();

      emit(
        state.copyWith(
          loading: false,
          toast: "Found ${availableBackups.length} backups files",
          availableBackups: availableBackups,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: "Failed to read all backups: $e",
        ),
      );
    }
  }

  void disconnect() => GoogleDriveApi.disconnect();
}
