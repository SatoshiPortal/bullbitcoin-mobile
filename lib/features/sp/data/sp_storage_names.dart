/// Names the SP account uses on disk. Must match what bwk writes, so they live
/// with the data layer that reads and clears them.
abstract class SpStorageNames {
  /// Account directory under the app documents dir, also the bwk account name.
  static const String accountName = 'sp';

  /// Sentinel file placed inside `{appDocs}/{accountName}` BEFORE the account
  /// dir is recursively deleted on revoke. If the delete subsequently fails
  /// (e.g. transient file-locked on Android/iOS because the SP notification
  /// thread still holds the sqlite handle, or iOS document-protection
  /// denial), the repository refuses to load any wallet from a dir containing
  /// this file. This prevents a stale on-disk wallet from being reloaded
  /// after a failed revoke.
  static const String revokedSentinelFile = '.revoked';

  /// bwk's per-directory advisory-lock sentinel, `{accountName}/.lock`. bwk
  /// holds an OS flock on it to refuse a second CROSS-process opener; on mobile
  /// there is only one process, so a lock present at open time is always a
  /// disposed session whose Rust handle Dart has not GC'd yet. The repository
  /// clears it before reopening (sqlite WAL keeps the brief in-process overlap
  /// safe). Must match bwk persist's lock filename.
  static const String lockFile = '.lock';

  /// The header store's own advisory-lock sentinel. It lives in the same
  /// directory but locks a per-file path rather than the shared `.lock`, so
  /// clearing only [lockFile] leaves this one held and the next create fails
  /// with "already opened by another instance". Must match bwk's header
  /// backend filename plus persist's lock suffix.
  static const String headerLockFile = 'headers.bin.lock';

  /// Every advisory lock the repository clears before reopening an account.
  static const List<String> lockFiles = [lockFile, headerLockFile];
}
