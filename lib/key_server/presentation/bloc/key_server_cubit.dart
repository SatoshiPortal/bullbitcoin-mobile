import 'package:bb_mobile/_core/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/validators/secret_validator.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_server_state.dart';
part 'key_server_cubit.freezed.dart';

//TODO; Re-initalie tor connection check on all keyserver operations
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
  final CreateBackupKeyFromDefaultSeedUsecase
      createBackupKeyFromDefaultSeedUsecase;
  KeyServerCubit({
    required this.checkServerConnectionUsecase,
    required this.createBackupKeyFromDefaultSeedUsecase,
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
      await checkConnection();
      await _handleServerOperation(
        () => trashKeyFromServerUsecase.execute(
          password: '',
          backupFileAsString: '',
        ),
        'Delete Key',
      );
      emit(state.copyWith(secretStatus: SecretStatus.deleted));
    } catch (e) {
      if (e is KeyServerError) {
        emit(
          state.copyWith(
            status: KeyServerOperationStatus.failure(message: e.message),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: const KeyServerOperationStatus.failure(
              message: 'Failed to delete key. Please try again.',
            ),
          ),
        );
      }
    }
  }

  void enterKey(String value) {
    if (state.secret.length >= pinMax) return;
    updateKeyServerState(
      secret: state.authInputType == AuthInputType.pin
          ? state.secret + value
          : value,
    );
  }

  Future<void> autoFetchKey() async {
    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));
      final backupInfo = BackupInfo(
        encrypted: state.encrypted,
      );
      final backupKey = await createBackupKeyFromDefaultSeedUsecase
          .execute(backupInfo.path ?? '');

      if (backupKey.isNotEmpty) {
        updateKeyServerState(
          backupKey: backupKey,
          status: const KeyServerOperationStatus.success(),
        );
      }
    } catch (e) {
      debugPrint('Generate key error: $e');
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.failure(
            message: 'Failed to generate key. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> recoverKey() async {
    if (!state.canProceed) return;

    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));

      if (state.authInputType == AuthInputType.backupKey) {
        emit(
          state.copyWith(
            backupKey: state.backupKey,
            secretStatus: SecretStatus.recovered,
            status: const KeyServerOperationStatus.success(),
          ),
        );
      } else {
        if (state.encrypted.isEmpty) {
          _emitOperationStatus(
            const KeyServerOperationStatus.failure(
              message: 'No backup key found. Please try again.',
            ),
          );
          return;
        }
        try {
          await checkConnection();
          final backupKey = await _handleServerOperation(
            () => restoreBackupKeyFromPasswordUsecase.execute(
              backupAsString: state.encrypted,
              password: state.secret,
            ),
            'Recover Key',
          );

          if (backupKey.isNotEmpty) {
            updateKeyServerState(
              backupKey: backupKey,
              secretStatus: SecretStatus.recovered,
              status: const KeyServerOperationStatus.success(),
            );
          }
        } on KeyServerError catch (e) {
          debugPrint('Key server error: ${e.message}');
          emit(
            state.copyWith(
              status: KeyServerOperationStatus.failure(message: e.message),
            ),
          );
        } catch (e) {
          debugPrint('Unexpected error during key recovery: $e');
          emit(
            state.copyWith(
              status: const KeyServerOperationStatus.failure(
                message: 'Failed to recover key. Please try again.',
              ),
            ),
          );
        }
      }
    } on KeyServerError catch (e) {
      emit(
        state.copyWith(
          status: KeyServerOperationStatus.failure(message: e.message),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.failure(
              message: 'Failed to recover key. Please try again.'),
        ),
      );
    }
  }

  Future<void> storeKey() async {
    if (!state.canProceed || !state.areKeysMatching) return;

    try {
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.loading(),
        ),
      );

      await checkConnection();

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

      emit(
        state.copyWith(
          secretStatus: SecretStatus.stored,
          status: const KeyServerOperationStatus.success(),
          currentFlow: CurrentKeyServerFlow.enter,
        ),
      );
    } catch (e) {
      debugPrint('Store key error: $e');
      if (e is KeyServerError) {
        emit(
          state.copyWith(
            status: KeyServerOperationStatus.failure(message: e.message),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: const KeyServerOperationStatus.failure(
              message: 'Failed to store key. Please try again.',
            ),
          ),
        );
      }
    }
  }

  void toggleObscure() =>
      emit(state.copyWith(isSecretObscured: !state.isSecretObscured));
  void toggleAuthInputType(AuthInputType newType) {
    if (newType == AuthInputType.backupKey &&
        state.currentFlow != CurrentKeyServerFlow.recovery) {
      return;
    }

    updateKeyServerState(
      authInputType: newType,
      secret: '',
      backupKey: '',
      resetState: true,
    );
  }

  void setBackupKey(String value) {
    emit(state.copyWith(backupKey: value));
  }

  Future<void> pasteBackupKey(String backupKey) async {
    setBackupKey(backupKey);
  }

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

  void _emitOperationStatus(KeyServerOperationStatus status) =>
      emit(state.copyWith(status: status));
  Future<T> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    emit(
      state.copyWith(
        status: const KeyServerOperationStatus.loading(),
        torStatus: TorStatus.connecting,
      ),
    );

    try {
      if (operation == checkServerConnectionUsecase.execute) {
        // Only retry for connection checks
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
            final isLastAttempt = attempt == maxRetries - 1;
            if (isLastAttempt) {
              throw 'Key service unavailable. Please check your connection.';
            }
            await Future.delayed(retryDelay);
          }
        }
      } else {
        // Execute other operations only once
        final result = await operation();
        emit(
          state.copyWith(
            status: const KeyServerOperationStatus.success(),
            torStatus: TorStatus.online,
          ),
        );
        return result;
      }
    } catch (e) {
      debugPrint('$operationName failed: ${(e as KeyServerError).message}');
      throw 'Key service unavailable. Please check your connection.';
    }
    throw Exception('Unexpected error in $operationName');
  }
}
