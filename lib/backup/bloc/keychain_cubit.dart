import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/backup/bloc/keychain_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recoverbull_dart/recoverbull_dart.dart';

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit() : super(const KeychainState());

  void clearError() => state.copyWith(error: '');

  void updateSecret(String value) => emit(state.copyWith(secret: value));
  void confirmSecret(String value) =>
      emit(state.copyWith(secretConfirmed: state.secret == value));

  Future<void> clickSecureKey(String backupId, String backupKey) async {
    if (state.secret.isEmpty || !state.secretConfirmed) {
      emit(state.copyWith(error: 'confirm your secret'));
      return;
    }

    ///TODO: check if the backup is already saved
    ///TODO: if it is, then show a toast

    // if (keychainapi.isEmpty) {
    //   emit(state.copyWith(error: 'keychain api is not set'));
    //   return;
    // }
    await _storeBackupKey(backupId, backupKey);
    emit(state.copyWith(completed: true));
  }

  Future<void> _storeBackupKey(String backupId, String backupKey) async {
    try {
      await KeyManagementService(keychainapi: keychainapi)
          .storeBackupKey(backupId, backupKey, state.secret);
    } catch (e) {
      emit(state.copyWith(error: 'Failed to store backup key on server'));
    }
  }
}
