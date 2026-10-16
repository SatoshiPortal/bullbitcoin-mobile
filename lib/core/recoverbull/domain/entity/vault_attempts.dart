/// What the key server's public attempts snapshot says about one vault.
///
/// The snapshot counts every PIN or password tried on the vault during the
/// server's cooldown window, the owner's included. It cannot tell who tried.
class VaultAttempts {
  final int failedAttempts;

  const VaultAttempts({required this.failedAttempts})
    : assert(failedAttempts >= 0);

  /// No entry in the snapshot: nobody tried this vault in the window.
  const VaultAttempts.none() : failedAttempts = 0;

  bool get hasFailedAttempts => failedAttempts > 0;
}
