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
    if (state.key.isEmpty) return;
    _updateKey(state.key.substring(0, state.key.length - 1));
  }

  Future<void> checkConnection() async {
    await _handleServerOperation(
      checkServerConnectionUsecase.execute,
      'Check Connection',
    );
  }

  void clearError() => _emitStatus(const KeyServerOperationStatus.initial());

  Future<void> confirmKey() async {
    if (!state.canProceed) return;

    if (state.selectedFlow == KeyServerFlow.enter) {
      emit(
        state.copyWith(
          selectedFlow: KeyServerFlow.confirm,
          tempKey: state.key,
          key: '',
        ),
      );
      return;
    }

    if (!state.areKeysMatching) {
      _emitStatus(
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
    if (state.key.length >= pinMax) return;
    _updateKey(state.key + value);
  }

  Future<void> recoverKey() async {
    if (!state.canProceed) return;
    try {
      final backupKey = await _handleServerOperation(
        () => restoreBackupKeyFromPasswordUsecase.execute(
          backupAsString: '',
          password: state.key,
        ),
        'Recover Key',
      );
      if (backupKey != null) {
        emit(
          state.copyWith(
            backupKey: backupKey,
            secretStatus: SecretStatus.recovered,
          ),
        );
      }
    } catch (e) {
      _emitError('Failed to recover key: $e');
    }
  }

  void setFlow(KeyServerFlow flow) {
    emit(
      state.copyWith(
        selectedFlow: flow,
        status: const KeyServerOperationStatus.initial(),
        key: '',
        tempKey: '',
        isKeyConfirmed: false,
        backupKey: '',
      ),
    );
  }

  Future<void> storeKey() async {
    if (!state.canProceed || !state.areKeysMatching) return;
    try {
      final derivedKey = await deriveBackupKeyFromDefaultWalletUsecase.execute(
        backupFileAsString: '',
      );
      await _handleServerOperation(
        () => storeBackupKeyIntoServerUsecase.execute(
          password: state.key,
          backupKey: derivedKey,
          backupFileAsString: '',
        ),
        'Store Key',
      );
      emit(state.copyWith(secretStatus: SecretStatus.stored));
    } catch (e) {
      _emitError('Failed to store key: $e');
    }
  }

  void toggleObscure() => emit(state.copyWith(obscure: !state.obscure));

  // Private helper methods
  Future<T?> _handleServerOperation<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    _emitLoading();
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final result = await operation();
        _emitSuccess();
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

  void _emitError(String message) => emit(
        state.copyWith(
          status: KeyServerOperationStatus.failure(message: message),
          torStatus: TorStatus.offline,
        ),
      );

  void _emitLoading() => emit(
        state.copyWith(
          status: const KeyServerOperationStatus.loading(),
          torStatus: TorStatus.connecting,
        ),
      );

  void _emitSuccess() => emit(
        state.copyWith(
          status: const KeyServerOperationStatus.success(),
          torStatus: TorStatus.online,
        ),
      );

  void _emitStatus(KeyServerOperationStatus status) =>
      emit(state.copyWith(status: status));

  void _updateKey(String value) => emit(
        state.copyWith(
          key: value,
          status: const KeyServerOperationStatus.initial(),
          isKeyConfirmed: false,
        ),
      );
}
