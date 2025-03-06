import 'dart:async';

import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/recoverbull/tor_connection.dart';
import 'package:bb_mobile/recoverbull/bloc/keychain_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

class KeychainCubit extends Cubit<KeychainState> {
  static const pinMin = 6;
  static const pinMax = 8;
  static const maxRetries = 2;
  static const retryDelay = Duration(seconds: 1);
  final TorConnection _connection;
  KeyService? _currentService;

  KeychainCubit()
      : _connection = TorConnection(),
        super(const KeychainState()) {
    _initialize();
  }

  Future<T?> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName, {
    bool emitState = true,
  }) async {
    try {
      if (emitState) emit(state.copyWith(loading: true, error: ''));
      final result = await _withRetries(() => operation(), operationName);
      if (emitState) {
        emit(state.copyWith(keyServerUp: true, loading: false));
      }
      return result;
    } catch (e) {
      debugPrint('$operationName failed: $e');
      if (emitState) {
        emit(state.copyWith(
          keyServerUp: false, // Only set to false for server operations
          loading: false,
          error:
              'Unable to complete $operationName. Please check your connection.',
        ));
      }
      return null;
    }
  }

  Future<KeyService> _createKeyService() async {
    if (!_connection.isInitialized) {
      await _handleServerOperation(
        () async {
          await _connection.initialize();
          await Future.delayed(const Duration(seconds: 5));
        },
        'Tor initialization',
        emitState: false,
      );
    }

    final service = KeyService(
      keyServer: Uri.parse(onionUrl),
      keyServerPublicKey: keyServerPublicKey,
      tor: _connection.tor,
    );

    await _handleServerOperation(
      () async => await service.serverInfo(),
      'Service verification',
      emitState: false,
    );

    return service;
  }

  Future<void> _initialize() async {
    if (keyServerUrl.isEmpty) {
      emit(state.copyWith(
        error: 'Keyserver connection failed',
        loading: false,
        keyServerUp: false,
      ));
      return;
    }

    try {
      emit(state.copyWith(loading: true, error: ''));
      _currentService = await _createKeyService();
      await _connection.ready;
      await keyServerStatus();
    } catch (e) {
      debugPrint('KeychainCubit initialization error: $e');
      emit(state.copyWith(
        error: 'Keyserver connection failed',
        loading: false,
        keyServerUp: false,
      ));
    }
  }

  Future<void> keyServerStatus() async {
    if (_currentService == null) {
      emit(state.copyWith(
        keyServerUp: false,
        error: 'Connection not initialized',
        loading: false,
      ));
      return;
    }

    if (state.isInCooldown) {
      emit(
        state.copyWith(
          keyServerUp: false,
          error:
              'Rate limited. Please wait ${state.remainingCooldownSeconds} seconds.',
          loading: false,
        ),
      );
      return;
    }

    if (!isClosed) {
      await _handleServerOperation(
        () async => await _currentService?.serverInfo(),
        'Key server status',
      );
    }
  }

  Future<bool> _ensureServerStatus() async {
    if (_currentService == null) {
      await _initialize();
    }
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
      emit(state.copyWith(
        loading: false,
        keySecretState: KeySecretState.recovered,
      ));
      return;
    }
    if (!await _ensureServerStatus()) return;

    try {
      emit(state.copyWith(loading: true, error: ''));
      final backupKey = await _currentService?.fetchBackupKey(
        backupId: state.backupId,
        password: state.secret,
        salt: state.backupSalt,
      );

      if (backupKey != null) {
        emit(state.copyWith(
          backupKey: HEX.encode(backupKey),
          loading: false,
          keySecretState: KeySecretState.recovered,
        ));
      }
    } catch (e) {
      debugPrint("Failed to recover backup key: $e");
      emit(state.copyWith(
        error: 'Failed to recover backup key',
        loading: false,
        keyServerUp: false,
      ));
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

      await _currentService?.trashBackupKey(
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
      await _currentService?.storeBackupKey(
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

  @override
  Future<void> close() {
    // Don't dispose of the connection manager here since it's shared
    return super.close();
  }

  /// Executes an async operation with retry logic
  ///
  /// Parameters:
  ///   - action: The async operation to execute
  ///   - operationName: Name of the operation for logging purposes
  ///
  /// Returns the result of type T from the action if successful
  /// Will attempt the operation up to [maxRetries] times with [retryDelay] between attempts
  /// Logs each retry attempt and final failure if all attempts fail
  Future<T> _withRetries<T>(
      Future<T> Function() action, String operationName) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isLastAttempt = attempt == maxRetries - 1;
        debugPrint(isLastAttempt
            ? '$operationName failed after $maxRetries attempts: $e'
            : 'Retrying $operationName (${attempt + 1}/$maxRetries)');

        if (isLastAttempt) rethrow;
        await Future.delayed(retryDelay);
      }
    }
    // This return is only to satisfy Dart's control flow analysis
    // The function will either return from the try block or rethrow in the catch
    return await action();
  }
}
