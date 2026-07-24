part of 'bloc.dart';

enum RecoverBullFlow {
  secureVault,
  recoverVault,
  testVault,
  viewVaultKey,
  settings,
}

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
    @Default(null) RecoverBullFailure? failure,
    @Default(KeyServerStatus.unknown) KeyServerStatus keyServerStatus,
    @Default(false) bool isFlowFinished,
    @Default(TorStatus.unknown) TorStatus torStatus,
    // Mirrors `OnboardingState`'s birthday-picker pause fields (see that
    // bloc's doc): set once vault decryption succeeds for
    // `RecoverBullFlow.recoverVault` if the restored default Bitcoin
    // wallet is about to opt into compact block filters.
    // `FetchVaultKeyPage`'s `BlocListener` shows `WalletBirthdayPicker`
    // when [needsBitcoinBirthdaySelection] turns true, then dispatches
    // `OnBitcoinBirthdayResolved` with the result — [decryptedVault]
    // already carries the mnemonic to restore, so nothing else needs to be
    // threaded through.
    @Default(false) bool needsBitcoinBirthdaySelection,
    @Default(false) bool pendingRestoreIsTestnet,
  }) = _RecoverBullState;

  const RecoverBullState._();
}
