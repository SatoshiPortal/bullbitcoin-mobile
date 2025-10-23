part of 'bloc.dart';

enum RecoverBullFlow { secureVault, recoverVault, testVault, viewVaultKey }

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
    @Default(null) BullError? error,
  }) = _RecoverBullState;

  const RecoverBullState._();
}
