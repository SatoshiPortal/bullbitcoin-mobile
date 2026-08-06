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

/// The persisted `/attempts` polling state for one key-server URL.
///
/// Domain mirror of the telemetry baseline: the drift row type stays behind
/// the repository, so the core layer never depends on the storage schema.
/// Scoped per server URL — identifiers and snapshots from different servers
/// are unrelated.
class TelemetryServerState {
  final String serverUrl;

  /// The last ETag served by `/attempts`, sent back as `If-None-Match`.
  final String? lastEtag;
  final DateTime? lastSuccessfulCheckAt;

  /// The server's `attempts_collection_started_at`. A change means the server
  /// wiped its counters: reset the baseline, never raise an attack alarm.
  final DateTime? collectionStartedAt;

  /// Consecutive failed polls, driving the prolonged-unavailability warning.
  final int consecutiveFailures;

  /// When the prolonged-unavailability warning was last shown (dedup).
  final DateTime? unavailabilityWarnedAt;

  const TelemetryServerState({
    required this.serverUrl,
    this.lastEtag,
    this.lastSuccessfulCheckAt,
    this.collectionStartedAt,
    this.consecutiveFailures = 0,
    this.unavailabilityWarnedAt,
  });

  TelemetryServerState copyWith({
    String? lastEtag,
    bool clearLastEtag = false,
    DateTime? lastSuccessfulCheckAt,
    DateTime? collectionStartedAt,
    bool clearCollectionStartedAt = false,
    int? consecutiveFailures,
    DateTime? unavailabilityWarnedAt,
  }) => TelemetryServerState(
    serverUrl: serverUrl,
    lastEtag: clearLastEtag ? null : (lastEtag ?? this.lastEtag),
    lastSuccessfulCheckAt: lastSuccessfulCheckAt ?? this.lastSuccessfulCheckAt,
    collectionStartedAt: clearCollectionStartedAt
        ? null
        : (collectionStartedAt ?? this.collectionStartedAt),
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    unavailabilityWarnedAt:
        unavailabilityWarnedAt ?? this.unavailabilityWarnedAt,
  );
}

/// The persisted own-operation baseline for one monitored backup.
///
/// [backupIdHash] is `sha256(raw backup id)` — the same value the server
/// publishes in `/attempts`. The raw backup id is never persisted.
class TelemetryBackupState {
  final String serverUrl;
  final String backupIdHash;

  /// The server's authoritative distinct-candidate total as of this device's
  /// last own operation in [currentWindow] — the count we expect to still see
  /// if nothing foreign happened since.
  ///
  /// Deliberately NOT a local operation counter: the server counts distinct
  /// authentication candidates, so replaying a password adds nothing, and an
  /// operation-based counter would drift above the server's total and absorb
  /// an attacker's probes. Another device sharing the backup still produces a
  /// conservative false positive, handled by the copy ("was it you or another
  /// device?") plus acknowledgement memory.
  final int expectedTotalAttempts;

  /// The window [expectedTotalAttempts] belongs to, as the shared window
  /// identity (see [telemetryWindowIdentity]). A mismatch means the local
  /// counter is stale and must reset before any comparison.
  final int? currentWindow;

  /// Window identity of the last warning shown for this backup (dedup).
  final int? lastWarningWindow;

  /// When the user last acknowledged a warning for this backup.
  final DateTime? acknowledgedAt;

  const TelemetryBackupState({
    required this.serverUrl,
    required this.backupIdHash,
    this.expectedTotalAttempts = 0,
    this.currentWindow,
    this.lastWarningWindow,
    this.acknowledgedAt,
  });

  TelemetryBackupState copyWith({
    int? expectedTotalAttempts,
    int? currentWindow,
    bool clearCurrentWindow = false,
    int? lastWarningWindow,
    DateTime? acknowledgedAt,
  }) => TelemetryBackupState(
    serverUrl: serverUrl,
    backupIdHash: backupIdHash,
    expectedTotalAttempts: expectedTotalAttempts ?? this.expectedTotalAttempts,
    currentWindow: clearCurrentWindow
        ? null
        : (currentWindow ?? this.currentWindow),
    lastWarningWindow: lastWarningWindow ?? this.lastWarningWindow,
    acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
  );
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
