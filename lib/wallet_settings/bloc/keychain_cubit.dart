import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/wallet_settings/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class KeychainCubit extends Cubit<KeychainState> {
  KeychainCubit() : super(const KeychainState()) {
    _init();
  }

  void _init() => shuffleAndEmit();

  void shuffleAndEmit() {
    final shuffledList = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle();
    emit(
      state.copyWith(
        shuffledNumbers: shuffledList,
        error: '',
      ),
    );
  }

  void changeInputType(KeyChainInputType type) {
    emit(
      state.copyWith(
        inputType: type,
        pin: [],
        password: '',
        error: '',
        pageState: KeyChainPageState.enter,
        tempPin: '',
        tempPassword: '',
        pinConfirmed: false,
        passwordConfirmed: false,
      ),
    );
  }

  void keyPressed(String key) {
    if (state.pin.length >= 6) return;
    emit(
      state.copyWith(
        pin: List<String>.from(state.pin)..add(key),
        error: '',
      ),
    );
  }

  void backspacePressed() {
    if (state.pin.isEmpty) return;
    emit(
      state.copyWith(
        pin: List<String>.from(state.pin)..removeLast(),
        error: '',
      ),
    );
  }

  void passwordChanged(String password) {
    emit(
      state.copyWith(
        password: password,
        error: '',
      ),
    );
  }

  void clearError() => emit(
        state.copyWith(
          error: '',
        ),
      );
  void clearSensitive() {
    clearError();
    emit(
      state.copyWith(
        pin: [],
        password: '',
        tempPin: '',
        tempPassword: '',
        pinConfirmed: false,
        passwordConfirmed: false,
      ),
    );
  }

  void confirmPressed() {
    if (!state.showButton()) return;

    state.inputType == KeyChainInputType.pin
        ? _confirmPin()
        : _confirmPassword();
  }

  void _confirmPin() {
    if (state.pageState == KeyChainPageState.enter) {
      if (state.pin.length < 6) {
        emit(state.copyWith(error: 'PIN must be at least 6 digits'));
        return;
      }

      emit(
        state.copyWith(
          pageState: KeyChainPageState.confirm,
          tempPin: state.pin.join(),
          pin: [],
          error: '',
        ),
      );
      return;
    }

    if (state.pin.join() != state.tempPin) {
      emit(
        state.copyWith(
          pageState: KeyChainPageState.enter,
          tempPin: '',
          pin: [],
          error: 'PINs do not match. Please try again.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        pinConfirmed: true,
        error: '',
      ),
    );
  }

  void _confirmPassword() {
    if (!state.isPasswordValid) {
      emit(state.copyWith(error: 'Password must be at least 6 characters'));
      return;
    }

    if (state.pageState == KeyChainPageState.enter) {
      emit(
        state.copyWith(
          pageState: KeyChainPageState.confirm,
          tempPassword: state.password,
          password: '',
          error: '',
        ),
      );
      return;
    }

    if (state.password != state.tempPassword) {
      emit(
        state.copyWith(
          pageState: KeyChainPageState.enter,
          tempPassword: '',
          password: '',
          error: 'Passwords do not match. Please try again.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        passwordConfirmed: true,
        error: '',
      ),
    );
  }

  Future<void> secureKey(
    String backupId,
    String backupKey,
    String backupSalt,
  ) async {
    final pinOrPassword = state.inputType == KeyChainInputType.pin
        ? state.tempPin
        : state.tempPassword;
    try {
      emit(state.copyWith(saving: true, error: ''));
      await KeyService(keyServer: Uri.parse(keychainapi)).storeBackupKey(
        backupId: backupId,
        password: pinOrPassword,
        backupKey: HEX.decode(backupKey),
        salt: HEX.decode(backupSalt),
      );

      emit(state.copyWith(saved: true, saving: false));
    } catch (e) {
      debugPrint('Failed to store backup key on server: $e');
      emit(
        state.copyWith(
          saving: false,
          error: 'Failed to store backup key on server',
          passwordConfirmed: false,
        ),
      );
    }
  }
}
