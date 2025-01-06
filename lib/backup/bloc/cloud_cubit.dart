import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/_pkg/gdrive.dart';
import 'package:bb_mobile/backup/bloc/cloud_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      final gdrive = await Gdrive.connect();

      if (gdrive != null) {
        emit(state.copyWith(gdrive: gdrive));
        print("User has logged in" + "Sign in");
      } else {
        print("User has not logged in" + "Sign in");
      }
    } catch (e) {
      print(e);
    }

    if (state.gdrive == null) {
      emit(state.copyWith(toast: 'not connected'));
      return;
    }

    final backup = File(backupPath);
    final content = await backup.readAsString();

    final bool isCreated = await state.gdrive!.write(
      filename: backupName,
      content: json.decode(content) as Map<dynamic, dynamic>,
    );

    if (isCreated == false) {
      emit(state.copyWith(toast: "Not created"));
    } else {
      emit(state.copyWith(toast: "File created successfully."));
    }
  }

  void disconnect() => Gdrive.disconnect();
}
