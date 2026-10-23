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

    /// The full readiness snapshot, not just the coarse status.
    ///
    /// The screen needs `fraction` for progress and `blockage` to say *why*
    /// Tor is stuck; deriving those from a coarse status enum is impossible
    /// because it collapses all three into four values.
    @Default(tor.TorUninitialized()) tor.TorConnectionState torConnection,
  }) = _RecoverBullState;

  const RecoverBullState._();
}
