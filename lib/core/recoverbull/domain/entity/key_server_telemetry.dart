/// Domain mirror of the key server's telemetry types. The core layer maps
/// the recoverbull SDK types into these at the repository boundary, so
/// usecases and entities stay free of SDK types.
///
/// All telemetry is advisory: the server cannot distinguish an attacker
/// from the user or another of the user's devices, and a compromised server
/// can fabricate or suppress counters.
library;

/// Exact attempt counters for one identifier's current rate-limit window,
/// as returned on a successful `/fetch` or `/trash`.
class KeyServerAttemptStatus {
  final int totalAttempts;
  final int failedAttempts;
  final int remainingAttempts;
  final DateTime windowStartedAt;
  final DateTime? previousAttemptAt;
  final DateTime resetsAt;

  const KeyServerAttemptStatus({
    required this.totalAttempts,
    required this.failedAttempts,
    required this.remainingAttempts,
    required this.windowStartedAt,
    required this.previousAttemptAt,
    required this.resetsAt,
  });
}

/// The recovered vault key plus the identifier's attempt counters. Null
/// status against older servers: skip reconciliation rather than treat a
/// fabricated value as authoritative.
class VaultKeyFetchResult {
  /// Hex-encoded vault key.
  final String vaultKey;
  final KeyServerAttemptStatus? attemptStatus;

  const VaultKeyFetchResult({
    required this.vaultKey,
    required this.attemptStatus,
  });
}

/// One entry of the public `/attempts` snapshot (hour-truncated timestamps).
class KeyServerAttemptEntry {
  /// SHA-256 over the raw identifier bytes.
  final String idHash;
  final int totalAttempts;
  final int failedAttempts;
  final DateTime windowStartedAt;
  final DateTime lastAttemptAt;

  const KeyServerAttemptEntry({
    required this.idHash,
    required this.totalAttempts,
    required this.failedAttempts,
    required this.windowStartedAt,
    required this.lastAttemptAt,
  });
}

/// The result of a conditional `GET /attempts`.
sealed class TelemetrySnapshotResult {
  const TelemetrySnapshotResult();
}

/// The snapshot is unchanged since the caller's ETag.
class TelemetrySnapshotNotModified extends TelemetrySnapshotResult {
  const TelemetrySnapshotNotModified();
}

/// A fresh snapshot was downloaded.
class TelemetrySnapshotModified extends TelemetrySnapshotResult {
  /// Persist and send back as `If-None-Match` on the next poll.
  final String? etag;
  final int? maxAgeSeconds;
  final DateTime collectionStartedAt;

  /// Total entries before filtering: compare with the server's
  /// `maxAttemptIdentifiers` to detect map pressure.
  final int totalEntries;

  /// Only the entries matching the monitored backup identifiers.
  final List<KeyServerAttemptEntry> matchingEntries;

  const TelemetrySnapshotModified({
    required this.etag,
    required this.maxAgeSeconds,
    required this.collectionStartedAt,
    required this.totalEntries,
    required this.matchingEntries,
  });
}

/// The window identity used for reconciliation, as epoch seconds.
///
/// The server serves the SAME window at two precisions: `attempt_status`
/// (direct response) carries the exact second, while the public `/attempts`
/// snapshot is hour-truncated on purpose (exact timestamps would ease
/// correlation). Comparing the two for equality without normalizing would
/// therefore mismatch on every reconciliation and raise a false
/// "unknown activity" alert on the user's own recovery.
///
/// Both sides are compared at hour granularity. Two distinct windows can only
/// collide inside the same hour, which requires a cooldown shorter than an
/// hour — far below the 24h production value.
int telemetryWindowIdentity(DateTime windowStartedAt) {
  final utc = windowStartedAt.toUtc();
  final truncated = DateTime.utc(utc.year, utc.month, utc.day, utc.hour);
  return truncated.millisecondsSinceEpoch ~/ 1000;
}

/// The server info's telemetry metadata.
class KeyServerInfo {
  /// Start of the server's attempt collection: changes on restart/wipe.
  final DateTime? collectionStartedAt;

  /// Capacity of the server's rate-limit map.
  final int? maxAttemptIdentifiers;

  const KeyServerInfo({
    required this.collectionStartedAt,
    required this.maxAttemptIdentifiers,
  });
}
