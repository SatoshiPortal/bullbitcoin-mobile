import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class KeychainCubit extends Cubit<KeychainState> {
  static const pinMin = 6;
  static const pinMax = 8;

  KeychainCubit() : super(const KeychainState()) {
    _initialize();
  }

  late final KeyService _keyService;

  void _initialize() {
    shuffleAndEmit();
    if (keyServerUrl.isEmpty) {
      emit(
        state.copyWith(
          error: 'keychain api is not set',
          keyServerUp: false,
        ),
      );
      return;
    }

    _keyService = KeyService(
      keyServer: Uri.parse(keyServerUrl),
      keyServerPublicKey: keyServerPublicKey,
    );

    // Initial status check
    keyServerStatus();
  }

  Future<void> keyServerStatus() async {
    if (!isClosed) {
      try {
        final info = await _keyService.serverInfo();
        final isUp = info.cooldown <= 1;

        if (isUp != state.keyServerUp) {
          emit(state.copyWith(keyServerUp: isUp));
        }
      } catch (e) {
        debugPrint('Server status check failed: $e');
        if (state.keyServerUp) {
          emit(state.copyWith(keyServerUp: false));
        }
      }
    }
  }

  Future<bool> _ensureServerStatus() async {
    await keyServerStatus();
    return state.keyServerUp;
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

  void clickObscure() => emit(state.copyWith(obscure: !state.obscure));

  Future<void> clickRecover() async {
    if (state.backupKey.isNotEmpty) {
      emit(
        state.copyWith(
          loading: false,
          keySecretState: KeySecretState.recovered,
        ),
      );
      return;
    }

    final isServerReady = await serverInfo();
    if (!isServerReady) return;
    if (state.secret.length < pinMin) {
      state.inputType == KeyChainInputType.pin
          ? emit(
              state.copyWith(
                error: 'pin should be at least $pinMin digits long',
              ),
            )
          : emit(
              state.copyWith(
                error: 'password should be at least $pinMin characters long',
              ),
            );
      return;
    }

    try {
      emit(state.copyWith(loading: true, error: ''));

      final backupKey = await _keyService.fetchBackupKey(
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
        state.copyWith(loading: false, error: "Failed to recover backup key"),
      );
    }
  }

  Future confirmPressed() async {
    if (!await _ensureServerStatus()) return;
    if (!state.canStoreKey) return;
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

  Future<void> deleteBackupKey() async {
    if (!await _ensureServerStatus()) return;
    if (!state.canDeleteKey) return;
    try {
      emit(state.copyWith(loading: true, error: ''));
      final isServerReady = await serverInfo();
      if (!isServerReady) return;

      await _keyService.trashBackupKey(
        backupId: state.backupId,
        password: state.secret,
        salt: state.backupSalt,
      );
      emit(
        state.copyWith(
          loading: false,
          keySecretState: KeySecretState.deleted,
        ),
      );
    } catch (e) {
      debugPrint('Failed to delete backup key: $e');
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to delete backup key',
        ),
      );
    }
  }

  void keyPressed(String key) {
    if (state.secret.length >= pinMax) return;
    emit(state.copyWith(secret: state.secret + key, error: ''));
  }

  Future<void> secureKey() async {
    if (!await _ensureServerStatus()) return;
    try {
      final isServerReady = await serverInfo();
      if (!isServerReady) return;

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

  void setBackupId(String id) {
    emit(state.copyWith(backupId: id));
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

  void shuffleAndEmit() {
    final shuffledList = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle();
    emit(state.copyWith(shuffledNumbers: shuffledList));
  }

  void updateBackupKey(String value) {
    emit(
      state.copyWith(
        backupKey: value,
        error: '',
      ),
    );
  }

  void updateInput(String value) {
    if (state.inputType == KeyChainInputType.pin && value.length > 6) return;
    emit(state.copyWith(secret: value, error: ''));
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

  Future<bool> serverInfo() async {
    emit(state.copyWith(loading: true));
    try {
      final info = await _keyService.serverInfo();
      if (info.cooldown > 1) {
        emit(state.copyWith(loading: false, error: 'Server is on cooldown'));
        return false;
      }
      if (state.tempSecret.length > info.secretMaxLength ||
          state.secret.length > info.secretMaxLength) {
        emit(state.copyWith(loading: false, error: 'Secret is too long'));
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Failed to get server info: $e');
      emit(
        state.copyWith(
          loading: false,
          error: 'Key server is not reachable! Please try again later',
        ),
      );
      return false;
    }
  }
}
