part of 'bloc.dart';

@MappableClass(generateMethods: GenerateMethods.equals | GenerateMethods.copy)
final class RecoverBullState with RecoverBullStateMappable {
  final RecoverBullFlow flow;
  final VaultProvider? vaultProvider;
  final EncryptedVault? vault;
  final String? vaultKey;
  final String? vaultPassword;
  final bool isLoading;
  final RecoverBullFailure? failure;
  final KeyServerStatus keyServerStatus;

  /// Failed checks on the current route; retries are explicitly user-requested.
  final int keyServerFailures;
  final int keyServerAttempt;
  final int keyServerAttempts;
  final bool isFlowFinished;

  /// The full readiness snapshot, not just the coarse status.
  ///
  /// The screen needs `fraction` for progress and `blockage` to say *why*
  /// Tor is stuck; deriving those from a coarse status enum is impossible
  /// because it collapses all three into four values.
  final tor.TorConnectionState torConnection;

  const RecoverBullState({
    required this.flow,
    this.vaultProvider,
    this.vault,
    this.vaultKey,
    this.vaultPassword,
    this.isLoading = false,
    this.failure,
    this.keyServerStatus = KeyServerStatus.unknown,

    this.keyServerFailures = 0,
    this.keyServerAttempt = 0,
    this.keyServerAttempts = 0,
    this.isFlowFinished = false,
    this.torConnection = const tor.TorUninitialized(),
  });

  @override
  String toString() => 'RecoverBullState(flow: $flow, sensitive: <redacted>)';
}
