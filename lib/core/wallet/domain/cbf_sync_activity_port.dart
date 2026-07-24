/// Capability to learn whether a wallet's compact block filter (CBF) sync
/// currently has a native session running, and to wait for one to settle,
/// without ever requesting its cancellation.
///
/// Exists so normal app code — a receive-address reveal, a backend switch
/// back to Electrum, or wallet deletion — can defer a BDK-mutating
/// operation instead of racing (or killing) a session `CbfWalletDatasource`
/// still owns. Per the product rule this exists to enforce, only
/// `CbfWalletDatasource`'s own foreground-lifecycle and Tor guards may ever
/// shut an active session down; every other caller must wait or refuse.
///
/// The canonical implementation is `CbfWalletDatasource` itself — the only
/// actor that owns an in-flight session — reading straight off the same
/// in-memory attempt registry `startSync` populates synchronously, before
/// any progress event is emitted. An implementation must never derive
/// [isActive]/[waitUntilInactive] from `WalletSyncRepository
/// .watchProgress()` (or any other event stream) instead: a session is
/// registered the instant `startSync` is called, but the corresponding
/// `WalletSyncStarted` event can lag behind it by one or more async gaps
/// (native session setup, an already-pending Tor check) — a
/// stream-derived observer queried in that window would wrongly report
/// the wallet as inactive and let a second BDK handle start mutating
/// concurrently. Querying the actor's own state has no such window.
abstract interface class CbfSyncActivityPort {
  /// Whether [walletId] currently has an in-flight CBF sync attempt.
  bool isActive({required String walletId});

  /// Resolves immediately if [walletId] has no active CBF sync right now;
  /// otherwise resolves once the current attempt settles — completed,
  /// failed, or cancelled by something other than this call. Never itself
  /// requests cancellation.
  Future<void> waitUntilInactive({required String walletId});
}
