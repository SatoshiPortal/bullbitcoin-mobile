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

  // Helper methods for common state updates
  void _emitError(String error) {
    emit(state.copyWith(
      error: error,
      loading: false,
      // Reset error state when new error occurs
      secretStatus: SecretStatus.initial,
    ));
  }

  void _emitLoading() {
    emit(state.copyWith(loading: true, error: ''));
  }

  void _emitSuccess({SecretStatus? keySecretState}) {
    emit(state.copyWith(
      loading: false,
      error: '', // Clear any errors
      secretStatus: keySecretState ?? state.secretStatus,
    ));
  }

  // Core operations
  Future<void> _initialize() async {
    try {
      _emitLoading();
      if (_currentService == null || !_connection.isInitialized) {
        _currentService = await _createKeyService();
      }
      await _connection.ready;
    } catch (e) {
      debugPrint('Failed to initialize keyserver connection: $e');
      emit(state.copyWith(
        error: 'Service unavailable. Please check your connection.',
        loading: false,
        torStatus: TorStatus.offline,
      ));
    }
  }

  Future<KeyService> _createKeyService() async {
    if (!_connection.isInitialized) {
      // Initialize Tor with retry logic and delayed start
      await _handleServerOperation(
        () async {
          await _connection.initialize();
          await Future.delayed(const Duration(seconds: 5));
        },
        'Tor initialization',
        emitState: false, // Don't emit states during service creation
      );
    }

    final service = KeyService(
      keyServer: Uri.parse(keyServerUrl),
      tor: _connection.tor,
    );

    // Verify service can connect to server
    await _handleServerOperation(
      () async => await service.serverInfo(),
      'Service verification',
      emitState: false, // Don't emit states during service creation
    );

    return service;
  }

  Future<void> _initialize() async {
    if (keyServerUrl.isEmpty) {
      emit(
        state.copyWith(
          error: 'Keyserver connection failed',
          loading: false,
          keyServerUp: false,
        ),
      );
      return;
    }

    try {
      emit(state.copyWith(loading: true, error: ''));
      _currentService = await _createKeyService();
      await _connection.ready;
      await keyServerStatus();
    } catch (e) {
      debugPrint('KeychainCubit initialization error: $e');
      emit(
        state.copyWith(
          error: 'Keyserver connection failed',
          loading: false,
          keyServerUp: false,
        ),
      );
    }
  }

  Future<void> keyServerStatus() async {
    if (_currentService == null) {
      emit(
        state.copyWith(
          keyServerUp: false,
          error: 'Connection not initialized',
          loading: false,
        ),
      );
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
      // Check server status with retry logic and state management
      await _handleServerOperation(
        () async => await _currentService?.serverInfo(),
        'Key server status',
        // emitState: true (default) - Update UI with server status
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
    try {
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

      final service = _currentService;
      final backup = state.backupData;

      if (service == null || backup == null) {
        emit(
          state.copyWith(
            error: 'Missing backup data or service connection',
            loading: false,
          ),
        );
        return;
      }

      emit(state.copyWith(loading: true, error: ''));

      final backupKey = await service.fetchBackupKey(
        backupId: backup.id,
        password: state.secret,
        salt: HEX.decode(backup.salt),
      );

      emit(
        state.copyWith(
          backupKey: HEX.encode(backupKey),
          loading: false,
          keySecretState: KeySecretState.recovered,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to recover backup key',
          loading: false,
        ),
      );
      return;
    }
  }

  Future<void> secureKey() async {
    final backup = state.backupData;
    if (backup == null || state.backupKey.isEmpty || state.tempSecret.isEmpty) {
      _emitError('Missing backup data or credentials');
      return;
    }

    if (!await _ensureServerStatus()) return;

    try {
      _emitLoading();
      await _currentService!.storeBackupKey(
        backupId: backup.id,
        password: state.tempSecret,
        backupKey: HEX.decode(state.backupKey),
        salt: HEX.decode(backup.salt),
      );
      _emitSuccess(keySecretState: SecretStatus.stored);
    } catch (e) {
      _emitError('Failed to store backup key: $e');
    }

    emit(state.copyWith(isSecretConfirmed: true));
  }

  Future<void> deleteBackupKey() async {
    try {
      if (!await _ensureServerStatus()) return;
      if (!state.canDeleteKey) return;

      final service = _currentService;
      final backup = state.backupData;

      if (service == null || backup == null) {
        emit(
          state.copyWith(
            error: 'Missing backup data or service connection',
            loading: false,
          ),
        );
        return;
      }

      emit(state.copyWith(loading: true, error: ''));

      await service.trashBackupKey(
        backupId: backup.id,
        password: state.secret,
        salt: HEX.decode(backup.salt),
      );

      emit(
        state.copyWith(
          loading: false,
          keySecretState: KeySecretState.deleted,
        ),
      );
      return;
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Failed to delete backup key',
          loading: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isSecretConfirmed: true));
  }

  void keyPressed(String key) {
    if (state.secret.length >= pinMax) return;
    emit(state.copyWith(secret: state.secret + key, error: ''));
  }

  Future<void> secureKey() async {
    try {
      if (!await _ensureServerStatus()) return;

      final service = _currentService;
      final backup = state.backupData;

      if (service == null || backup == null) {
        emit(
          state.copyWith(
            error: 'Missing backup data or service connection',
            loading: false,
          ),
        );
        return;
      }

      if (state.backupKey.isEmpty || state.tempSecret.isEmpty) {
        emit(
          state.copyWith(
            error: 'Missing backup key or password',
            loading: false,
          ),
        );
        return;
      }

      emit(state.copyWith(loading: true, error: ''));
      await service.storeBackupKey(
        backupId: backup.id,
        password: state.tempSecret,
        backupKey: HEX.decode(state.backupKey),
        salt: HEX.decode(backup.salt),
      );

      emit(
        state.copyWith(
          loading: false,
          keySecretState: KeySecretState.saved,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to store backup key',
        ),
      );
      return;
    }
  }

  void updateChainState(
    KeyChainPageState keyChainPageState,
    String? backupKey,
    BullBackup? backupData,
  ) {
    emit(
      state.copyWith(
        pageState: keyChainPageState,
        originalPageState: keyChainPageState, // Store original state
        backupKey: backupKey ?? '',
        backupData: backupData,
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

  /// Handles server operations with retry logic and state management
  ///
  /// Returns the operation result or null if all attempts fail
  /// Updates keyServerUp status based on operation success/failure when emitState is true
  /// Will attempt the operation multiple times with delay between attempts
  Future<T?> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName, {
    bool emitState = true,
    int maxAttempts = maxRetries,
    Duration? delay,
  }) async {
    if (emitState) emit(state.copyWith(loading: true, error: ''));

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final result = await operation();
        if (emitState) {
          emit(state.copyWith(keyServerUp: true, loading: false));
        }
        return result;
      } catch (e) {
        final isLastAttempt = attempt == maxAttempts - 1;
        debugPrint(
          isLastAttempt
              ? '$operationName failed after $maxAttempts attempts: $e'
              : 'Retrying $operationName (${attempt + 1}/$maxAttempts)',
        );

        if (isLastAttempt) {
          if (emitState) {
            emit(
              state.copyWith(
                keyServerUp: false,
                loading: false,
                error:
                    'Unable to complete $operationName. Please check your connection.',
              ),
            );
          }
          return null;
        }
        await Future.delayed(delay ?? retryDelay);
      }
    }
    return null;
  }
}
