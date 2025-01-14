import 'dart:io';

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
      final googleSignInAccount = await GoogleDriveApi.google.signIn();
      final googleDriveStorage = await GoogleDriveStorage.connect(
        googleSignInAccount,
        defaultCloudBackupPath,
      );
      if (googleSignInAccount != null) {
        emit(state.copyWith(googleDriveStorage: googleDriveStorage));
        debugPrint("User has logged in");
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
      emit(state.copyWith(toast: "File created successfully."));
    }
  }

  void disconnect() => GoogleDriveApi.disconnect();
}
