import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import '../recoverbull_failure.dart';
import '../entities/attempt_monitoring_snapshot.dart';
import '../entities/attempt_monitoring_state.dart';
import '../entities/drive_backup_cache_entry.dart';
import '../entities/key_server_attempts.dart';
import '../entities/monitored_backup.dart';

abstract interface class RecoverBullAttemptMonitoringRemotePort {
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  });
}

/// Optimistic snapshot writes reject changes after capture, including reset.
abstract interface class RecoverBullAttemptMonitoringRepository {
  @useResult
  Future<Result<List<MonitoredBackup>, RecoverBullFailure>> monitoredBackups();

  @useResult
  Future<Result<Null, RecoverBullFailure>> replaceBackup(
    AttemptMonitoringBackupState value, {
    RecoverBullAttemptMonitoringSnapshotToken? token,
  });

  @useResult
  Future<Result<bool, RecoverBullFailure>> isMonitored(List<int> identifier);

  @useResult
  Future<Result<Null, RecoverBullFailure>> removeBackup(String backupIdHex);

  List<int> digestFor(List<int> identifier);

  @useResult
  Future<Result<Null, RecoverBullFailure>> registerBackup(
    List<int> identifier, {
    MonitoredBackupOrigin origin = MonitoredBackupOrigin.created,
    int observedTotal = 0,
    int window = 0,
    RecoverBullAttemptMonitoringSnapshotToken? token,
    String? driveAccount,
    String? driveFileId,
    DateTime? driveFileCreatedAt,
    DateTime? driveFileModifiedAt,
  });

  @useResult
  Future<Result<Null, RecoverBullFailure>> purgeDriveAccount(String account);

  @useResult
  Future<Result<List<MonitoredBackup>, RecoverBullFailure>> driveBackups(
    String account,
  );

  @useResult
  Future<Result<List<DriveBackupCacheEntry>, RecoverBullFailure>> driveCache(
    String account,
  );

  @useResult
  Future<Result<Null, RecoverBullFailure>> saveDriveCache({
    required String account,
    required String driveFileId,
    required List<int> backupDigest,
    required DateTime createdAt,
    DateTime? modifiedAt,
  });

  @useResult
  Future<Result<bool, RecoverBullFailure>> reconcileDriveBackups(
    String account,
    List<DriveBackupObservation> observations,
  );

  @useResult
  Future<Result<Null, RecoverBullFailure>> recordStatus(
    List<int> identifier,
    KeyServerAttemptStatus status,
  );

  @useResult
  Future<Result<Null, RecoverBullFailure>> recordOwnAttempt(
    List<int> identifier, {
    required int serverTotalAttempts,
    required DateTime window,
  });

  @useResult
  Future<Result<AttemptMonitoringState, RecoverBullFailure>> state();

  @useResult
  Future<Result<RecoverBullAttemptMonitoringSnapshotToken, RecoverBullFailure>>
  captureToken();

  @useResult
  Future<Result<RecoverBullAttemptMonitoringApplyResult, RecoverBullFailure>>
  applySnapshot(
    RecoverBullAttemptsSnapshot snapshot, [
    RecoverBullAttemptMonitoringSnapshotToken? token,
  ]);

  @useResult
  Future<Result<RecoverBullAttemptMonitoringApplyResult, RecoverBullFailure>>
  rebaseline(
    RecoverBullAttemptsSnapshot snapshot,
    RecoverBullAttemptMonitoringSnapshotToken token,
  );

  @useResult
  Future<Result<bool, RecoverBullFailure>> recordPollFailure({
    required DateTime now,
  });

  @useResult
  Future<Result<Null, RecoverBullFailure>> recordAttemptsUnsupported({
    required DateTime until,
    RecoverBullAttemptMonitoringSnapshotToken? token,
  });

  @useResult
  Future<Result<Set<String>, RecoverBullFailure>> acknowledgedAlertIdentities();

  @useResult
  Future<Result<Null, RecoverBullFailure>> acknowledgeAlert(
    String identity, {
    required DateTime at,
  });

  @useResult
  Future<Result<Null, RecoverBullFailure>> setEnabled(bool enabled);

  @useResult
  Future<Result<Null, RecoverBullFailure>> reset();
}
