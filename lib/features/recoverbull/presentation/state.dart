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

    /// Which key-server attempt is in flight, and out of how many.
    ///
    /// Reaching the server is an onion-service lookup — a descriptor fetch then
    /// a rendezvous — which routinely needs more than one try just after a cold
    /// bootstrap. Showing the count is the difference between "it is retrying"
    /// and "it is frozen".
    @Default(0) int keyServerAttempt,
    @Default(0) int keyServerAttempts,
    @Default(false) bool isFlowFinished,

    /// The full readiness snapshot, not just the coarse status.
    ///
    /// The screen needs `fraction` for progress and `blockage` to say *why*
    /// Tor is stuck; deriving those from [TorStatus] is impossible because it
    /// collapses all three into four values.
    @Default(tor.TorUninitialized()) tor.TorConnectionState torConnection,
  }) = _RecoverBullState;

  const RecoverBullState._();
}
