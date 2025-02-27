import 'dart:async';

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
    if (state.isInCooldown) {
      emit(state.copyWith(
        keyServerUp: false,
        error:
            'Rate limited. Please wait ${state.remainingCooldownSeconds} seconds.',
        loading: false,
      ));
      return;
    }

    emit(state.copyWith(loading: true, error: ''));

    if (!isClosed) {
      try {
        final info = await _keyService.serverInfo();
        debugPrint('Server info: $info');
        emit(state.copyWith(
          keyServerUp: true,
          loading: false,
          lastRequestTime: null,
          cooldownMinutes: null,
          error: '',
        ));
      } catch (e) {
        final errorStr = e.toString();

        if (errorStr.contains('Failed host lookup') ||
            errorStr.contains('SocketException') ||
            errorStr.contains('Connection refused')) {
          debugPrint('Connection issue: $errorStr');
          emit(state.copyWith(
            keyServerUp: false,
            loading: false,
            error:
                'Unable to reach key server. This could be due to network issues or the server may be temporarily unavailable.',
          ));
        } else if (errorStr.contains('429')) {
          final cooldownMatch = RegExp(r'cooldown: (\d+)').firstMatch(errorStr);
          final dateMatch =
              RegExp(r'requestedAt: ([^,\)]+)').firstMatch(errorStr);

          final cooldownMinutes = cooldownMatch != null
              ? int.tryParse(cooldownMatch.group(1) ?? '0')
              : 1;

          final requestedAt = dateMatch != null
              ? DateTime.tryParse(dateMatch.group(1) ?? '')
              : DateTime.now();

          emit(state.copyWith(
            keyServerUp: true, // Server is reachable but rate-limited
            loading: false,
            lastRequestTime: requestedAt ?? DateTime.now(),
            cooldownMinutes: cooldownMinutes,
            error: 'Rate limited. Please wait $cooldownMinutes minutes.',
          ));
        } else {
          debugPrint('Server status check failed: $e');
          emit(state.copyWith(
            keyServerUp: false,
            loading: false,
            error: 'Key server is not responding. Please try again later.',
          ));
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
    if (!await _ensureServerStatus()) return;
    print('_ensureServerStatus');
    // if (state.secret.length < pinMin) {
    //   state.inputType == KeyChainInputType.pin
    //       ? emit(
    //           state.copyWith(
    //             error: 'pin should be at least $pinMin digits long',
    //           ),
    //         )
    //       : emit(
    //           state.copyWith(
    //             error: 'password should be at least $pinMin characters long',
    //           ),
    //         );
    //   return;
    // }

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
    if (id == state.backupId) return; // Avoid duplicate state
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
        originalPageState: keyChainPageState, // Store original state
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
    if (value == state.backupKey) return; // Avoid duplicate state
    emit(state.copyWith(backupKey: value, error: ''));
  }

  void updateInput(String value) {
    if (state.inputType == KeyChainInputType.pin && value.length > 6) return;
    if (value == state.secret) return; // Avoid duplicate state

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
}
