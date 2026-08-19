/// Thrown when a local database file exists but its encryption key can
/// not be obtained from secure storage, and the key's absence is
/// *permanent* rather than temporary.
///
/// This is the fail-closed path: the databases on disk are encrypted
/// with a key we no longer have, so there is nothing to read and
/// generating a replacement key would only produce a second, equally
/// unreadable database on top of the user's data.
///
/// Deliberately distinct from `KeychainLockedException`, which means
/// "the key is very probably there, the device just hasn't been
/// unlocked since boot". Conflating the two is what turns a five-second
/// wait into a data wipe, so the two never share a catch clause:
///
/// - `KeychainLockedException` → wait, retry after unlock, change nothing.
/// - [DatabaseKeyUnavailableException] → offer the user an explicit,
///   confirmed local-data reset. Never reset without asking.
///
/// The realistic way to reach this on iOS is restoring an iCloud/iTunes
/// backup onto a *different* device: the databases come back but the
/// key, stored with `first_unlock_this_device`, does not. Excluding the
/// databases from backup (see `BackupExclusion`) is what stops that
/// combination from occurring in the first place; this exception is the
/// safety net for every case it doesn't cover (Keychain reset, partial
/// restore, an OS bug).
class DatabaseKeyUnavailableException implements Exception {
  /// Developer-facing detail. Logged, never rendered to the user — the
  /// recovery screen shows a localized message instead.
  final String reason;

  const DatabaseKeyUnavailableException(this.reason);

  @override
  String toString() => 'DatabaseKeyUnavailableException: $reason';
}
