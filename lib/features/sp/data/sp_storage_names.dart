/// Names the SP account uses on disk. Must match what bwk writes, so they live
/// with the data layer that reads and clears them.
abstract class SpStorageNames {
  /// Account directory under the app documents dir, also the bwk account name.
  static const String accountName = 'sp_v2';
  static const String legacyAccountName = 'sp';
  static const String identityMarker = '.sp_identity_v1';

  /// Sentinel file placed inside `{appDocs}/{accountName}` BEFORE the account
  /// dir is recursively deleted on revoke. If the delete subsequently fails
  /// (e.g. transient file-locked on Android/iOS because the SP notification
  /// thread still holds the sqlite handle, or iOS document-protection
  /// denial), the repository refuses to load any wallet from a dir containing
  /// this file. This prevents a stale on-disk wallet from being reloaded
  /// after a failed revoke.
  static const String revokedSentinelFile = '.revoked';

  /// Native advisory lock names; their presence does not prove ownership ended.
  static const String lockFile = '.lock';
  static const String headerLockFile = 'headers.bin.lock';
  static const List<String> lockFiles = [lockFile, headerLockFile];
}
