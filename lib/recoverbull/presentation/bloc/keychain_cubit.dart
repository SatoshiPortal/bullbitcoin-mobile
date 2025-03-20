import 'package:bb_mobile/recoverbull/domain/usecases/check_key_server_connection_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/derive_backup_key_from_default_wallet_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/restore_encrypted_vault_from_password_use_case.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/store_backup_key_into_server_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/usecases/trash_backup_key_from_server_usecase.dart';
import 'package:bb_mobile/recoverbull/domain/validators/secret_validator.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'keychain_state.dart';
part 'keychain_cubit.freezed.dart';

class KeychainCubit extends Cubit<KeychainState> {
  static const pinMin = 6;
  static const pinMax = 8;
  static const maxRetries = 2;
  static const retryDelay = Duration(seconds: 1);

  final StoreBackupKeyIntoServerUsecase storeBackupKeyIntoServerUsecase;
  final TrashBackupKeyFromServerUsecase trashBackupKeyFromServerUsecase;
  final DeriveBackupKeyFromDefaultWalletUsecase
      deriveBackupKeyFromDefaultWalletUsecase;
  final RestoreEncryptedVaultFromPasswordUsecase
      restoreEncryptedVaultFromFromPasswordUsecase;
  final CheckKeyServerConnectionUsecase checkKeyServerConnectionUsecase;
  KeychainCubit(
    this.storeBackupKeyIntoServerUsecase,
    this.trashBackupKeyFromServerUsecase,
    this.deriveBackupKeyFromDefaultWalletUsecase,
    this.restoreEncryptedVaultFromFromPasswordUsecase,
    this.checkKeyServerConnectionUsecase,
  ) : super(const KeychainState());

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
          status: const KeychainOperationStatus.loading(),
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
              status: const KeychainOperationStatus.success(),
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
          debugPrint(
            'Unable to complete $operationName. Please check your connection.',
          );
          if (emitState) {
            emit(
              state.copyWith(
                torStatus: TorStatus.offline,
                status: const KeychainOperationStatus.failure(
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
      emit(state.copyWith(status: const KeychainOperationStatus.initial()));
}
