import 'package:bb_mobile/_core/domain/usecases/create_backup_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/key_server/domain/validators/password_validator.dart';
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
  static const retryDelay = Duration(seconds: 4);

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
    if (state.password.isEmpty) return;
    updateKeyServerState(
      password: state.password.substring(0, state.password.length - 1),
    );
  }

  Future<void> checkConnection() async {
    emit(state.copyWith(torStatus: TorStatus.connecting));

    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await checkServerConnectionUsecase.execute();
        emit(state.copyWith(torStatus: TorStatus.online));
        return;
      } catch (e) {
        debugPrint('Connection attempt ${attempt + 1} failed: $e');

        if (attempt == maxRetries - 1) {
          emit(state.copyWith(torStatus: TorStatus.offline));
          throw const KeyServerError.failedToConnect();
        }

        // Only delay if we're going to retry
        await Future.delayed(retryDelay);
      }
    }
  }

  void clearError() =>
      _emitOperationStatus(const KeyServerOperationStatus.initial());
  void clearSensitive() => updateKeyServerState(
        password: '',
      );
  Future<void> confirmKey() async {
    if (!state.canProceed) return;

    if (state.currentFlow == CurrentKeyServerFlow.enter) {
      emit(
        state.copyWith(
          currentFlow: CurrentKeyServerFlow.confirm,
          temporaryPassword: state.password,
          password: '',
        ),
      );
      return;
    }

    if (!state.arePasswordsMatching) {
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
          backupFile: '',
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
    if (state.password.length >= pinMax) return;
    updateKeyServerState(
      password: state.authInputType == AuthInputType.pin
          ? state.password + value
          : value,
    );
  }

  Future<void> autoFetchKey() async {
    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));
      final backupInfo = BackupInfo(
        backupFile: state.backupFile,
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
        if (state.backupFile.isEmpty) {
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
              backupFile: state.backupFile,
              password: state.password,
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
            message: 'Failed to recover key. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> storeKey() async {
    if (!state.canProceed || !state.arePasswordsMatching) return;

    try {
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.loading(),
        ),
      );

      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        backupFile: state.backupFile,
      );

      await _handleServerOperation(
        () => storeBackupKeyIntoServerUsecase.execute(
          password: state.password,
          backupKey: derivedKey,
          backupFile: state.backupFile,
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
      emit(state.copyWith(isPasswordObscured: !state.isPasswordObscured));
  void toggleAuthInputType(AuthInputType newType) {
    if (newType == AuthInputType.backupKey &&
        state.currentFlow != CurrentKeyServerFlow.recovery) {
      return;
    }

    updateKeyServerState(
      authInputType: newType,
      password: '',
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
    String? password,
    String? backupKey,
    CurrentKeyServerFlow? flow,
    SecretStatus? secretStatus,
    KeyServerOperationStatus? status,
    AuthInputType? authInputType,
    String? backupFile,
    bool resetState = false,
  }) {
    // Prevent duplicate state updates
    if (!resetState &&
        password == state.password &&
        backupKey == state.backupKey &&
        flow == state.currentFlow &&
        authInputType == state.authInputType &&
        backupFile == state.backupFile) {
      return;
    }

    // Don't reset backupKey if it's a state change during backup flow
    final isBackupFlow = flow == CurrentKeyServerFlow.enter ||
        flow == CurrentKeyServerFlow.confirm;
    final shouldKeepBackupKey = isBackupFlow && state.backupKey.isNotEmpty;

    emit(
      state.copyWith(
        password: resetState ? '' : (password ?? state.password),
        backupKey: shouldKeepBackupKey
            ? state.backupKey
            : (resetState ? '' : (backupKey ?? state.backupKey)),
        currentFlow: flow ?? state.currentFlow,
        authInputType: authInputType ?? state.authInputType,
        backupFile: backupFile ?? state.backupFile,
        temporaryPassword: resetState ? '' : state.temporaryPassword,
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
      ),
    );

    try {
      // Always check connection before any key server operation
      await checkConnection();

      final result = await operation();
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.success(),
        ),
      );
      return result;
    } on KeyServerError catch (e) {
      debugPrint('$operationName failed: ${e.message}');
      emit(
        state.copyWith(
          status: KeyServerOperationStatus.failure(message: e.message),
        ),
      );
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error in $operationName: $e');
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.failure(
            message: 'Operation failed. Please check your connection.',
          ),
        ),
      );
      rethrow;
    }
  }
}
