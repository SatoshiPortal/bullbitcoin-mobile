import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/recover/bloc/keychain_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit({required String backupId, required this.filePicker})
      : super(KeychainState(backupId: backupId));

  final FilePick filePicker;

  void clearError() => emit(state.copyWith(error: ''));
  void updateSecret(String value) => emit(state.copyWith(secret: value));

  Future<void> clickRecoverKey() async {
    if (state.backupId.isEmpty) {
      emit(state.copyWith(error: 'backup id is missing'));
      return;
    }

    if (state.secret.length != 6) {
      emit(state.copyWith(error: 'pin should be 6 digits long'));
      return;
    }

    _recoverBackupKey(state.secret, state.backupId);
  }

  Future<void> _recoverBackupKey(String secret, String backupId) async {
    try {
      if (keychainapi.isEmpty) {
        emit(state.copyWith(error: 'keychain api is not set'));
        return;
      }
      final backupKey = await KeyManagementService(keychainapi: keychainapi)
          .recoverBackupKey(backupId, secret);
      emit(state.copyWith(backupKey: backupKey));
    } on KeyManagementException catch (e) {
      emit(state.copyWith(error: e.message));
    }
  }
}
