import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

@freezed
sealed class RecoverBullVaultRecoveryState
    with _$RecoverBullVaultRecoveryState {
  const factory RecoverBullVaultRecoveryState({
    RecoverBullVaultRecoveryError? error,
    @Default(null) DecryptedVault? decryptedVault,
    @Default(null) ({BigInt satoshis, int transactions})? bip84Status,
    @Default(false) bool isImported,
  }) = _RecoverBullVaultRecoveryState;

  const RecoverBullVaultRecoveryState._();
}
