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

  void clearToast() => state.copyWith(toast: '');

  Future<void> connectAndStoreBackup() async {
    try {
      final googleSignInAccount = await GoogleDriveApi.google.signIn();
      final googleDriveStorage = await GoogleDriveStorage.connect(
        googleSignInAccount,
        "bullbitcoin/backups",
      );
      if (googleSignInAccount != null) {
        emit(state.copyWith(googleDriveStorage: googleDriveStorage));
        debugPrint("User has logged in");
      } else {
        debugPrint("User has not logged in");
      }
    } catch (e) {
      debugPrint("GoogleDriveStorage.connect Error: $e");
    }

    if (state.googleDriveStorage == null) {
      emit(state.copyWith(toast: 'User has not logged in'));
      return;
    }

    final backup = File(backupPath);
    final content = await backup.readAsString();
    final decoded = HEX.decode(content);
    final isCreated =
        await state.googleDriveStorage?.writeMetaData(decoded, backupName);

    if (isCreated == false) {
      emit(state.copyWith(toast: "Failed to backup file to google drive."));
    } else {
      emit(state.copyWith(toast: "File created successfully."));
    }
  }

  void disconnect() => GoogleDriveApi.disconnect();
}
