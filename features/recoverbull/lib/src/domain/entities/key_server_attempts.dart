/// Domain types returned by the key-server `/attempts` endpoint.
final class KeyServerAttemptStatus {
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

final class VaultKeyFetchResult {
  final String vaultKey;
  final KeyServerAttemptStatus? attemptStatus;

  const VaultKeyFetchResult({
    required this.vaultKey,
    required this.attemptStatus,
  });
}

int attemptWindowIdentity(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
      ).millisecondsSinceEpoch ~/
      1000;
}

final class AttemptsServerState {
  final String serverUrl;
  final String? lastEtag;
  final DateTime? lastSuccessfulCheckAt;
  final DateTime? collectionStartedAt;
  final int consecutiveFailures;
  final DateTime? unavailabilityWarnedAt;

  const AttemptsServerState({
    required this.serverUrl,
    this.lastEtag,
    this.lastSuccessfulCheckAt,
    this.collectionStartedAt,
    this.consecutiveFailures = 0,
    this.unavailabilityWarnedAt,
  });
}

final class AttemptMonitoringBackupState {
  final String serverUrl;
  final String backupIdHash;
  final int expectedTotalAttempts;
  final int? currentWindow;
  final int? lastWarningWindow;

  const AttemptMonitoringBackupState({
    required this.serverUrl,
    required this.backupIdHash,
    this.expectedTotalAttempts = 0,
    this.currentWindow,
    this.lastWarningWindow,
  });
}

final class KeyServerInfo {
  final DateTime? collectionStartedAt;
  final int? maxAttemptIdentifiers;

  const KeyServerInfo({
    required this.collectionStartedAt,
    required this.maxAttemptIdentifiers,
  });
}
