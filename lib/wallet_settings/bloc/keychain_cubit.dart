import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/wallet_settings/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit() : super(const KeychainState()) {
    shuffleAndEmit();
    _initKeyService();
  }

  late final KeyService _keyService;

  void _initKeyService() {
    if (keyServerUrl.isEmpty) {
      emit(state.copyWith(error: 'keychain api is not set'));
      return;
    }
    _keyService = KeyService(
      keyServer: Uri.parse(keyServerUrl),
      keyServerPublicKey: keyServerPublicKey,
    );
  }

  void shuffleAndEmit() {
    final shuffledList = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle();
    emit(state.copyWith(shuffledNumbers: shuffledList));
  }

  void clickObscure() {
    emit(
      state.copyWith(obscure: !state.obscure),
    );
  }

  void setChainState(
    KeyChainPageState keyChainPageState,
    String backupId,
    String? backupKey,
    String backupSalt,
  ) {
    emit(
      state.copyWith(
        pageState: keyChainPageState,
        backupKey: backupKey ?? '',
        backupId: backupId,
        backupSalt: HEX.decode(backupSalt),
      ),
    );
  }

  void updatePageState(
    KeyChainInputType keyChainInputType,
    KeyChainPageState keyChainPageState,
  ) {
    emit(
      state.copyWith(
        inputType: keyChainInputType,
        pageState: keyChainPageState,
        error: '',
        secret: '',
        tempSecret: '',
        isSecretConfirmed: false,
      ),
    );
  }

  void updateInput(String value) {
    if (state.inputType == KeyChainInputType.pin && value.length > 6) return;
    emit(state.copyWith(secret: value, error: ''));
  }

  void backspacePressed() {
    if (state.secret.isEmpty) return;
    emit(
      state.copyWith(
        secret: state.secret.substring(0, state.secret.length - 1),
        error: '',
      ),
    );
  }

  void keyPressed(String key) {
    if (state.secret.length >= 7) return;
    emit(
      state.copyWith(
        secret: state.secret + key,
        error: '',
      ),
    );
  }

  void confirmPressed() {
    if (!state.showButton) return;

    if (state.pageState == KeyChainPageState.enter) {
      emit(
        state.copyWith(
          pageState: KeyChainPageState.confirm,
          tempSecret: state.secret,
          secret: '',
        ),
      );
      return;
    }

    if (state.secret != state.tempSecret) {
      emit(
        state.copyWith(
          pageState: KeyChainPageState.enter,
          error: 'Values do not match. Please try again.',
          secret: '',
          tempSecret: '',
        ),
      );
      return;
    }

    emit(state.copyWith(isSecretConfirmed: true));
  }

  Future<void> secureKey() async {
    try {
      emit(state.copyWith(loading: true, error: ''));
      await _keyService.storeBackupKey(
        backupId: state.backupId,
        password: state.tempSecret,
        backupKey: HEX.decode(state.backupKey),
        salt: state.backupSalt,
      );
      emit(
        state.copyWith(loading: false, keySecretState: KeySecretState.saved),
      );
    } catch (e) {
      debugPrint('Failed to store backup key on server: $e');
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to store backup key on server',
        ),
      );
    }
  }

  void clearSensitive() {
    emit(
      state.copyWith(
        secret: '',
        tempSecret: '',
        isSecretConfirmed: false,
        error: '',
      ),
    );
  }

  void setBackupId(String id) {
    emit(state.copyWith(backupId: id));
  }

  Future<void> clickRecoverKey() async {
    if (state.secret.length < 6) {
      state.inputType == KeyChainInputType.pin
          ? emit(state.copyWith(error: 'pin should be atleast 6 digits long'))
          : emit(
              state.copyWith(
                error: 'password should be atleast 6 characters long',
              ),
            );
      return;
    }

    try {
      emit(state.copyWith(loading: true, error: ''));

      final backupKey = await _keyService.recoverBackupKey(
        backupId: state.backupId,
        password: state.secret,
        salt: state.backupSalt,
      );

      emit(
        state.copyWith(
          backupKey: HEX.encode(backupKey),
          loading: false,
          keySecretState: KeySecretState.recovered,
        ),
      );
    } catch (e) {
      debugPrint("Failed to recover backup key: $e");
      emit(
        state.copyWith(
          loading: false,
          error: "Failed to recover backup key",
        ),
      );
    }
  }
}
