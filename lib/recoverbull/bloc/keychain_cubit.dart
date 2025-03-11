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
    emit(
      state.copyWith(
        error: error,
        loading: false,
        // Reset error state when new error occurs
        secretStatus: SecretStatus.initial,
      ),
    );
  }

  void _emitLoading() {
    emit(state.copyWith(loading: true, error: ''));
  }

  void _emitSuccess({SecretStatus? keySecretState}) {
    emit(
      state.copyWith(
        loading: false,
        error: '', // Clear any errors
        secretStatus: keySecretState ?? state.secretStatus,
      ),
    );
  }

  Future<bool> _ensureServerStatus() async {
    if (_currentService == null) {
      await _initialize();
    }
    await keyServerStatus();
    return state.keyServerUp;
  }

  Future<KeyService> _createKeyService() async {
    if (!_connection.isInitialized) {
      // Initialize Tor with retry logic and delayed start
      await _handleServerOperation(
        () async {
          await _connection.initialize();
          await Future.delayed(const Duration(seconds: 5));
        },
        'tor_initialization',
      );
    }

    final service = KeyService(
      keyServer: Uri.parse(keyServerUrl),
      tor: _connection.tor,
    );
    await _handleServerOperation(
      () async => await service.serverInfo(),
      'service_verification',
    );

    return service;
  }

  Future<void> _initialize() async {
    try {
      _emitLoading();
      if (_currentService == null || !_connection.isInitialized) {
        _currentService = await _createKeyService();
      }
      await _connection.ready;
    } catch (e) {
      debugPrint('Failed to initialize keyserver connection: $e');
      emit(
        state.copyWith(
          error: 'Service unavailable. Please check your connection.',
          loading: false,
          torStatus: TorStatus.offline,
        ),
      );
    }
  }

  Future<T?> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName, {
    bool emitState = true,
    int maxAttempts = maxRetries,
    Duration? delay,
  }) async {
    if (emitState) {
      emit(
        state.copyWith(
          loading: true,
          error: '',
          torStatus: TorStatus.connecting,
        ),
      );
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final result = await operation();
        if (emitState) {
          emit(state.copyWith(torStatus: TorStatus.online, loading: false));
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
          debugPrint(
            'Unable to complete $operationName. Please check your connection.',
          );
          if (emitState) {
            emit(
              state.copyWith(
                torStatus: TorStatus.offline,
                loading: false,
                error: 'Service unavailable. Please check your connection.',
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

  // Public methods (alphabetically ordered)
  void backspacePressed() {
    if (state.secret.isEmpty) return;
    updateState(
      secret: state.secret.substring(0, state.secret.length - 1),
    );
  }

  void clearSensitive() => updateState(resetState: true);

  void clickObscure() => emit(state.copyWith(obscure: !state.obscure));

  Future<void> clickRecover() async {
    try {
      if (state.backupKey.isNotEmpty) {
        emit(
          state.copyWith(
            loading: false,
            secretStatus: SecretStatus.recovered,
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
          secretStatus: SecretStatus.recovered,
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

  @override
  Future<void> close() {
    resetState();
    return super.close();
  }

  Future confirmPressed() async {
    if (!state.canStoreKey) return;
    if (state.selectedKeyChainFlow == KeyChainFlow.enter) {
      emit(
        state.copyWith(
          selectedKeyChainFlow: KeyChainFlow.confirm,
          tempSecret: state.secret,
          secret: '',
        ),
      );
      return;
    }

    if (state.secret != state.tempSecret) {
      emit(
        state.copyWith(
          selectedKeyChainFlow: KeyChainFlow.enter,
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

      if (!await _ensureServerStatus()) return;

      await service.trashBackupKey(
        backupId: backup.id,
        password: state.secret,
        salt: HEX.decode(backup.salt),
      );

      emit(
        state.copyWith(
          loading: false,
          secretStatus: SecretStatus.deleted,
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
  }

  void keyPressed(String key) {
    if (state.secret.length >= pinMax) return;
    updateState(secret: state.secret + key);
  }

  Future<void> keyServerStatus() async {
    if (_currentService == null) {
      emit(
        state.copyWith(
          torStatus: TorStatus.offline,
          error: 'Service unavailable. Please check your connection.',
          loading: false,
        ),
      );
      return;
    }

    if (state.isInCooldown) {
      emit(
        state.copyWith(
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
        'get_server_status',
      );
    }
  }

  void resetState() {
    emit(
      state.copyWith(
        secret: '',
        tempSecret: '',
        backupKey: '',
        error: '',
        isSecretConfirmed: false,
        secretStatus: SecretStatus.initial,
        selectedKeyChainFlow: KeyChainFlow.enter,
        authInputType: AuthInputType.pin,
        loading: false,
        obscure: false,
      ),
    );
  }

  Future<void> secureKey() async {
    // Prevent duplicate calls if already processing
    if (state.loading || state.secretStatus != SecretStatus.initial) return;

    final backup = state.backupData;
    if (backup == null ||
        backup.id.isEmpty ||
        state.tempSecret.isEmpty ||
        state.backupKey.isEmpty ||
        backup.salt.isEmpty) {
      if (backup == null) debugPrint('Missing backup data');
      if (backup?.id.isEmpty ?? true) debugPrint('Missing backup ID');
      if (state.tempSecret.isEmpty) debugPrint('Missing password');
      if (state.backupKey.isEmpty) debugPrint('Missing backup key');
      if (backup?.salt.isEmpty ?? true) debugPrint('Missing salt');
      _emitError('Corrupt backup file');
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
      debugPrint('Failed to store backup key: $e');
      _emitError('Failed to store backup key');
    }
  }

  void updateBackupKey(String value) => updateState(backupKey: value);

  void updateInput(String value) => updateState(secret: value);

  void updatePageState(
    AuthInputType keyChainInputType,
    KeyChainFlow keyChainPageState,
  ) {
    updateState(
      authInputType: keyChainInputType,
      keyChainFlow: keyChainPageState,
      resetState: true, // Reset sensitive data
    );
  }

  void updateState({
    String? secret,
    String? backupKey,
    KeyChainFlow? keyChainFlow,
    AuthInputType? authInputType,
    BullBackup? backupData,
    bool resetState = false,
  }) {
    // Prevent duplicate state updates
    if (!resetState &&
        secret == state.secret &&
        backupKey == state.backupKey &&
        keyChainFlow == state.selectedKeyChainFlow &&
        authInputType == state.authInputType &&
        backupData == state.backupData) {
      return;
    }

    // Don't reset backupKey if it's a state change during backup flow
    final isBackupFlow = keyChainFlow == KeyChainFlow.enter ||
        keyChainFlow == KeyChainFlow.confirm;
    final shouldKeepBackupKey = isBackupFlow && state.backupKey.isNotEmpty;

    emit(
      state.copyWith(
        secret: resetState ? '' : (secret ?? state.secret),
        // Keep backupKey if we're in backup flow
        backupKey: shouldKeepBackupKey
            ? state.backupKey
            : (resetState ? '' : (backupKey ?? state.backupKey)),
        selectedKeyChainFlow: keyChainFlow ?? state.selectedKeyChainFlow,
        authInputType: authInputType ?? state.authInputType,
        backupData: backupData ?? state.backupData,
        // Only reset tempSecret if explicitly requested
        tempSecret: resetState ? '' : state.tempSecret,
        isSecretConfirmed: resetState && state.isSecretConfirmed,
        error: '', // Always clear errors on state update
      ),
    );
  }
}
