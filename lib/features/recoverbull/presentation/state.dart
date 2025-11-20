part of 'bloc.dart';

enum RecoverBullFlow { secureVault, recoverVault, testVault, viewVaultKey }

enum KeyServerStatus { unknown, connecting, online, offline }

@freezed
sealed class RecoverBullState with _$RecoverBullState {
  const factory RecoverBullState({
    required RecoverBullFlow flow,
    @Default(null) VaultProvider? vaultProvider,
    @Default(null) EncryptedVault? vault,
    @Default(null) String? vaultKey,
    @Default(null) String? vaultPassword,
    @Default(null) DecryptedVault? decryptedVault,
    @Default(false) bool isLoading,
    @Default(null) RecoverBullError? error,
    @Default(KeyServerStatus.unknown) KeyServerStatus keyServerStatus,
    @Default(null) ({BigInt satoshis, int transactions})? bip84Status,
    @Default(null) ({BigInt satoshis, int transactions})? liquidStatus,
    @Default(false) bool isFlowFinished,
    @Default(TorStatus.unknown) TorStatus torStatus,
  }) = _RecoverBullState;

  const RecoverBullState._();
}
