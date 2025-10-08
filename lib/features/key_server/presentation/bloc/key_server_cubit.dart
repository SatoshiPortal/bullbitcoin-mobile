import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_vault_key_from_default_seed_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/restore_backup_key_from_password_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/features/key_server/domain/validators/password_validator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_server_cubit.freezed.dart';
part 'key_server_state.dart';

class KeyServerCubit extends Cubit<KeyServerState> {
  static const maxRetries = 2;
  static const retryDelay = Duration(seconds: 4);

  final StoreBackupKeyIntoServerUsecase storeBackupKeyIntoServerUsecase;
  final TrashBackupKeyFromServerUsecase trashKeyFromServerUsecase;
  final DeriveBackupKeyFromDefaultWalletUsecase
  deriveBackupKeyFromDefaultWalletUsecase;
  final RestoreVaultKeyFromPasswordUsecase restoreBackupKeyFromPasswordUsecase;
  final CheckKeyServerConnectionUsecase checkServerConnectionUsecase;
  final CreateVaultKeyFromDefaultSeedUsecase
  createVaultKeyFromDefaultSeedUsecase;
  final DecryptVaultUsecase decryptVaultUsecase;

  KeyServerCubit({
    required this.checkServerConnectionUsecase,
    required this.createVaultKeyFromDefaultSeedUsecase,
    required this.storeBackupKeyIntoServerUsecase,
    required this.trashKeyFromServerUsecase,
    required this.deriveBackupKeyFromDefaultWalletUsecase,
    required this.restoreBackupKeyFromPasswordUsecase,
    required this.decryptVaultUsecase,
  }) : super(const KeyServerState());

  Future<void> checkConnection() async {
    if (state.torStatus == TorStatus.connecting) {
      return;
    }

    try {
      await _handleServerOperation(
        checkServerConnectionUsecase.execute,
        'Check Connection',
      );
    } catch (e) {
      emit(
        state.copyWith(
          torStatus: TorStatus.offline,
          status: const KeyServerOperationStatus.failure(
            message: 'Connection failed. Please check Tor status.',
          ),
        ),
      );
    }
  }

  void clearError() =>
      _emitOperationStatus(const KeyServerOperationStatus.initial());

  void clearSensitive() => updateKeyServerState(password: '');

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

  void updatePassword(String value) {
    updateKeyServerState(password: value);
  }

  void updateVaultKey(String value) {
    updateKeyServerState(vaultKey: value);
  }

  void checkVaultIsNotNull() {
    if (state.vault != null) return;

    _emitOperationStatus(
      const KeyServerOperationStatus.failure(
        message: 'No vault found. Please try again.',
      ),
    );
  }

  Future<void> autoFetchKey() async {
    checkVaultIsNotNull();

    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));
      final vault = state.vault!;
      final vaultKey = await createVaultKeyFromDefaultSeedUsecase.execute(
        vault.derivationPath,
      );

      if (vaultKey.isNotEmpty) {
        updateKeyServerState(
          vaultKey: vaultKey,
          status: const KeyServerOperationStatus.success(),
        );
      }
    } catch (e) {
      log.severe('Generate key error: $e');
      emit(
        state.copyWith(
          status: const KeyServerOperationStatus.failure(
            message: 'Failed to generate key. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> recoverKeyFromVaultKey() async {
    if (!state.canProceed) return;

    checkVaultIsNotNull();

    try {
      final _ = decryptVaultUsecase.execute(
        vault: state.vault!,
        vaultKey: state.vaultKey,
      );

      emit(
        state.copyWith(
          secretStatus: SecretStatus.recovered,
          status: const KeyServerOperationStatus.success(),
        ),
      );
    } catch (e) {
      final error = KeyServerOperationStatus.failure(message: e.toString());
      emit(state.copyWith(status: error));
    }
  }

  Future<void> recoverKeyFromPassword() async {
    if (!state.canProceed) return;

    checkVaultIsNotNull();

    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));

      await checkConnection();
      final backupKey = await _handleServerOperation(
        () => restoreBackupKeyFromPasswordUsecase.execute(
          vault: state.vault!,
          password: state.password,
        ),
        'Recover Key',
      );

      if (backupKey.isNotEmpty) {
        updateKeyServerState(
          vaultKey: backupKey,
          secretStatus: SecretStatus.recovered,
          status: const KeyServerOperationStatus.success(),
        );
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
    // } on KeyServerError catch (e) {
    //   emit(
    //     state.copyWith(
    //       status: KeyServerOperationStatus.failure(message: e.message),
    //     ),
    //   );
    // } catch (e) {
    //   emit(
    //     state.copyWith(
    //       status: const KeyServerOperationStatus.failure(
    //         message: 'Failed to recover key. Please try again.',
    //       ),
    //     ),
    //   );
    // }
  }

  Future<void> storeKey() async {
    if (!state.canProceed ||
        !state.arePasswordsMatching ||
        state.vault == null) {
      return;
    }

    try {
      emit(state.copyWith(status: const KeyServerOperationStatus.loading()));

      await checkConnection();

      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        vault: state.vault!,
      );

      await _handleServerOperation(
        () => storeBackupKeyIntoServerUsecase.execute(
          password: state.password,
          vault: state.vault!,
          vaultKey: derivedKey,
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
    if (newType == AuthInputType.encryptionKey &&
        state.currentFlow != CurrentKeyServerFlow.recovery) {
      return;
    }

    updateKeyServerState(
      authInputType: newType,
      password: '',
      vaultKey: '',
      resetState: true,
    );
  }

  void setBackupKey(String value) {
    emit(state.copyWith(vaultKey: value));
  }

  Future<void> pasteBackupKey(String vaultKey) async {
    setBackupKey(vaultKey);
  }

  void updateKeyServerState({
    String? password,
    String? vaultKey,
    CurrentKeyServerFlow? flow,
    SecretStatus? secretStatus,
    KeyServerOperationStatus? status,
    AuthInputType? authInputType,
    EncryptedVault? vault,
    bool resetState = false,
  }) {
    // Prevent duplicate state updates
    if (!resetState &&
        password == state.password &&
        vaultKey == state.vaultKey &&
        flow == state.currentFlow &&
        authInputType == state.authInputType &&
        vault == state.vault) {
      return;
    }

    // Don't reset vaultKey if it's a state change during backup flow
    final isBackupFlow =
        flow == CurrentKeyServerFlow.enter ||
        flow == CurrentKeyServerFlow.confirm;
    final shouldKeepBackupKey = isBackupFlow && state.vaultKey.isNotEmpty;

    emit(
      state.copyWith(
        password: resetState ? '' : (password ?? state.password),
        vaultKey:
            shouldKeepBackupKey
                ? state.vaultKey
                : (resetState ? '' : (vaultKey ?? state.vaultKey)),
        currentFlow: flow ?? state.currentFlow,
        authInputType: authInputType ?? state.authInputType,
        vault: vault ?? state.vault,
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
        torStatus: TorStatus.connecting,
      ),
    );

    try {
      if (operation == checkServerConnectionUsecase.execute) {
        // Only retry failed connection checks

        for (
          var attempt = 0;
          (attempt < maxRetries && state.torStatus != TorStatus.online);
          attempt++
        ) {
          try {
            final result = await operation();
            emit(state.copyWith(torStatus: TorStatus.online));
            return result;
          } catch (e) {
            final isLastAttempt = attempt == maxRetries - 1;
            if (isLastAttempt) {
              emit(state.copyWith(torStatus: TorStatus.offline));
              throw KeyServerError.failedToConnect();
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
      log.severe('$operationName failed: ${(e as KeyServerError).message}');
      rethrow;
    }
    throw Exception('Unexpected error in $operationName');
  }
}
