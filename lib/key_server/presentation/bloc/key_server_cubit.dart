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
  static const pinMin = 6;
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
          status: const KeyServerOperationStatus.loading(),
          torStatus: TorStatus.connecting,
        ),
      );
    }

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final result = await operation();
        if (emitState) {
          emit(
            state.copyWith(
              torStatus: TorStatus.online,
              status: const KeyServerOperationStatus.success(),
            ),
          );
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
                torStatus: TorStatus.offline,
                status: const KeyServerOperationStatus.failure(
                  message: 'Service unavailable. Please check your connection.',
                ),
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

  void clearProcessState() =>
      emit(state.copyWith(status: const KeyServerOperationStatus.initial()));

  void updateKey(String value) {
    emit(
      state.copyWith(
        key: value,
        status: const KeyServerOperationStatus.initial(),
        isKeyConfirmed: false,
      ),
    );
  }

  void updateTempKey(String value) {
    emit(state.copyWith(
      tempKey: value,
      isKeyConfirmed: state.areKeysMatching && state.hasValidKeyLength,
      status: const KeyServerOperationStatus.initial(),
    ));
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

  void toggleObscure() {
    emit(state.copyWith(obscure: !state.obscure));
  }

  Future<void> checkConnection() async {
    await _handleServerOperation(
      checkServerConnectionUsecase.execute,
      'Check Connection',
    );
  }
}
