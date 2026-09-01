/// Persists whether the wallet may resume scanning on its own, and caches the
/// value so the sync path and the UI can read it without an await.
///
/// The cache lives here rather than in a separate holder so there is one owner
/// of the value: [isEnabledNow] is the cached view of what [save] last wrote
/// and what [warmUp] read back at startup.
abstract interface class SpAutoScanRepository {
  /// The cached choice. Enabled until the user turns it off, so a read before
  /// [warmUp] reports enabled rather than guessing.
  bool get isEnabledNow;

  /// Seed the cache from storage. Called once at startup.
  Future<void> warmUp();

  Future<void> save({required bool isEnabled});
}
