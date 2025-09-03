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
    @Default(null) ({BigInt satoshis, int transactions})? liquidStatus,
    @Default(false) bool isImported,
  }) = _RecoverBullVaultRecoveryState;

  const RecoverBullVaultRecoveryState._();

  BigInt get totalBalance {
    final bitcoinBalance = bip84Status?.satoshis ?? BigInt.zero;
    final liquidBalance = liquidStatus?.satoshis ?? BigInt.zero;
    return bitcoinBalance + liquidBalance;
  }

  int get totalTransactions {
    final bitcoinTransactions = bip84Status?.transactions ?? 0;
    final liquidTransactions = liquidStatus?.transactions ?? 0;
    return bitcoinTransactions + liquidTransactions;
  }

  bool get isStillLoading => bip84Status == null || liquidStatus == null;
}
