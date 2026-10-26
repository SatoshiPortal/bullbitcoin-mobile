import 'attempt_alert.dart';

final class RecoverBullAttemptsSnapshot {
  final String? etag;
  final DateTime collectionStartedAt;
  final Map<List<int>, int> totalAttempts;
  final Map<List<int>, DateTime> windowStartedAt;
  final bool serviceBusy;
  final bool notModified;

  /// The key server does not serve `/attempts` (it answers 404): monitoring
  /// has nothing to observe, which is not an outage.
  final bool serverUnsupported;
  final int? totalEntries;
  final int? maxAttemptIdentifiers;

  const RecoverBullAttemptsSnapshot({
    required this.collectionStartedAt,
    required this.totalAttempts,
    this.windowStartedAt = const {},
    this.etag,
    this.serviceBusy = false,
    this.notModified = false,
    this.serverUnsupported = false,
    this.totalEntries,
    this.maxAttemptIdentifiers,
  });
}

final class RecoverBullAttemptMonitoringSnapshotToken {
  final int generation;
  final int stateRevision;
  final Map<List<int>, int> rowRevisions;
  final String? etag;
  final Map<String, int> ownActivityRevisions;

  const RecoverBullAttemptMonitoringSnapshotToken({
    required this.generation,
    required this.stateRevision,
    required this.rowRevisions,
    required this.etag,
    this.ownActivityRevisions = const {},
  });
}

final class RecoverBullAttemptMonitoringApplyResult {
  final bool accepted;
  final int conflicts;
  final Set<String> eligibleDigests;
  final List<SuspiciousActivityAlert> alerts;

  const RecoverBullAttemptMonitoringApplyResult(
    this.accepted,
    this.conflicts, {
    this.eligibleDigests = const {},
    this.alerts = const [],
  });
}

final class DriveBackupObservation {
  final String fileId;
  final List<int> digest;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  const DriveBackupObservation({
    required this.fileId,
    required this.digest,
    required this.createdAt,
    required this.modifiedAt,
  });

  String get digestKey =>
      digest.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

final class RecoverBullPollFailureResult {
  final bool accepted;
  final bool shouldWarn;
  const RecoverBullPollFailureResult(this.accepted, this.shouldWarn);
}

/// Identifies one local request without retaining its credentials.
final class RecoverBullOwnAttemptOperation {
  final int id;
  final int generation;
  final String backupDigest;
  const RecoverBullOwnAttemptOperation({
    required this.id,
    required this.generation,
    required this.backupDigest,
  });
}
