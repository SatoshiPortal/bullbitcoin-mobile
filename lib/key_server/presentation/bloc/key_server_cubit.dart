import 'package:bb_mobile/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/validators/secret_validator.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_server_state.dart';
part 'key_server_cubit.freezed.dart';

class KeyServerCubit extends Cubit<KeyServerState> {
  static const pinMax = 8;
  static const maxRetries = 2;
  static const retryDelay = Duration(seconds: 1);

  final StoreBackupKeyIntoServerUsecase storeBackupKeyIntoServerUsecase;
  final TrashBackupKeyFromServerUsecase trashKeyFromServerUsecase;
  final DeriveBackupKeyFromDefaultWalletUsecase
      deriveBackupKeyFromDefaultWalletUsecase;
  final RestoreBackupKeyFromPasswordUsecase restoreBackupKeyFromPasswordUsecase;
  final CheckKeyServerConnectionUsecase checkServerConnectionUsecase;

  KeyServerCubit({
    required this.checkServerConnectionUsecase,
    required this.storeBackupKeyIntoServerUsecase,
    required this.trashKeyFromServerUsecase,
    required this.deriveBackupKeyFromDefaultWalletUsecase,
    required this.restoreBackupKeyFromPasswordUsecase,
  }) : super(const KeyServerState());

  void backspaceKey() {
    if (state.secret.isEmpty) return;
    updateKeyServerState(
      secret: state.secret.substring(0, state.secret.length - 1),
    );
  }

  Future<void> checkConnection() async {
    await _handleServerOperation(
      checkServerConnectionUsecase.execute,
      'Check Connection',
    );
  }

  void clearError() =>
      _emitOperationStatus(const KeyServerOperationStatus.initial());
  void clearSensitive() => updateKeyServerState(
        secret: '',
      );
  Future<void> confirmKey() async {
    if (!state.canProceed) return;

    if (state.currentFlow == CurrentKeyServerFlow.enter) {
      emit(
        state.copyWith(
          currentFlow: CurrentKeyServerFlow.confirm,
          temporarySecret: state.secret,
          secret: '',
        ),
      );
      return;
    }

    if (!state.areKeysMatching) {
      _emitOperationStatus(
        const KeyServerOperationStatus.failure(
          message: 'Keys do not match. Please try again.',
        ),
      );
      return;
    }

    await storeKey();
  }

  Future<void> deleteKey() async {
    if (!state.canProceed) return;
    try {
      await _handleServerOperation(
        () => trashKeyFromServerUsecase.execute(
          password: '',
          backupFileAsString: '',
        ),
        'Delete Key',
      );
      emit(state.copyWith(secretStatus: SecretStatus.deleted));
    } catch (e) {
      _emitError('Failed to delete key: $e');
    }
  }

  void enterKey(String value) {
    if (state.secret.length >= pinMax) return;
    updateKeyServerState(secret: state.secret + value);
  }

  Future<void> recoverKey() async {
    if (!state.canProceed) return;
    if (state.encrypted.isEmpty) {
      _emitOperationStatus(
        const KeyServerOperationStatus.failure(
          message: 'No backup key found. Please try again.',
        ),
      );
      return;
    }
    try {
      final backupKey = await _handleServerOperation(
        () => restoreBackupKeyFromPasswordUsecase.execute(
          backupAsString: state.encrypted,
          password: state.secret,
        ),
        'Recover Key',
      );
      if (backupKey != null) {
        updateKeyServerState(
          backupKey: backupKey,
          secretStatus: SecretStatus.recovered,
        );
      }
    } catch (e) {
      _emitError('Failed to recover key: $e');
    }
  }

  Future<void> storeKey() async {
    await checkConnection();

    if (!state.canProceed || !state.areKeysMatching) return;
    try {
      emit(state.copyWith(
        status: const KeyServerOperationStatus.loading(),
      ));

      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        backupFileAsString: state.encrypted,
      );

      await _handleServerOperation(
        () => storeBackupKeyIntoServerUsecase.execute(
          password: state.secret,
          backupKey: derivedKey,
          backupFileAsString: state.encrypted,
        ),
        'Store Key',
      );

      // Update all relevant state properties in a single emit
      emit(
        state.copyWith(
          secretStatus: SecretStatus.stored,
          status: const KeyServerOperationStatus.success(),
          currentFlow: CurrentKeyServerFlow
              .enter, // Reset flow to prevent confirm screen
        ),
      );
    } catch (e) {
      _emitError('Failed to store key: $e');
    }
  }

  void toggleObscure() =>
      emit(state.copyWith(isSecretObscured: !state.isSecretObscured));
  void toggleAuthInputType(AuthInputType newType) =>
      updateKeyServerState(authInputType: newType, resetState: true);

  void updateKeyServerState({
    String? secret,
    String? backupKey,
    CurrentKeyServerFlow? flow,
    SecretStatus? secretStatus,
    KeyServerOperationStatus? status,
    AuthInputType? authInputType,
    String? encrypted,
    bool resetState = false,
  }) {
    // Prevent duplicate state updates
    if (!resetState &&
        secret == state.secret &&
        backupKey == state.backupKey &&
        flow == state.currentFlow &&
        authInputType == state.authInputType &&
        encrypted == state.encrypted) {
      return;
    }

    // Don't reset backupKey if it's a state change during backup flow
    final isBackupFlow = flow == CurrentKeyServerFlow.enter ||
        flow == CurrentKeyServerFlow.confirm;
    final shouldKeepBackupKey = isBackupFlow && state.backupKey.isNotEmpty;

    emit(
      state.copyWith(
        secret: resetState ? '' : (secret ?? state.secret),
        backupKey: shouldKeepBackupKey
            ? state.backupKey
            : (resetState ? '' : (backupKey ?? state.backupKey)),
        currentFlow: flow ?? state.currentFlow,
        authInputType: authInputType ?? state.authInputType,
        encrypted: encrypted ?? state.encrypted,
        temporarySecret: resetState ? '' : state.temporarySecret,
        secretStatus: secretStatus ?? state.secretStatus,

        status: status ?? state.status, // Don't clear status automatically
      ),
    );
  }

  // Private helper methods

  void _emitError(String message) => emit(
        state.copyWith(
          status: KeyServerOperationStatus.failure(message: message),
          torStatus: TorStatus.offline,
        ),
      );

  void _emitOperationStatus(KeyServerOperationStatus status) =>
      emit(state.copyWith(status: status));
  Future<T?> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    emit(
      state.copyWith(
        status: const KeyServerOperationStatus.loading(),
        torStatus: TorStatus.connecting,
      ),
    );
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final result = await operation();
        emit(
          state.copyWith(
            status: const KeyServerOperationStatus.success(),
            torStatus: TorStatus.online,
          ),
        );
        return result;
      } catch (e) {
        if (attempt == maxRetries - 1) {
          _emitError('Service unavailable. Please check your connection.');
          return null;
        }
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }
}
