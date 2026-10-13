import '../domain/entities/attempt_alert.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import '../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../domain/entities/attempt_monitoring_state.dart';
import '../domain/entities/drive_backup_cache_entry.dart';
import '../domain/entities/key_server_attempts.dart';
import '../domain/entities/monitored_backup.dart';
import '../domain/recoverbull_failure.dart';

/// Maps persistence exceptions without changing optimistic token semantics.
final class RecoverBullAttemptMonitoringRepositoryImpl
    implements RecoverBullAttemptMonitoringRepository {
  final RecoverBullAttemptMonitoringStore _store;
  final LogSink log;

  const RecoverBullAttemptMonitoringRepositoryImpl(
    this._store, {
    required this.log,
  });

  Future<Result<T, RecoverBullFailure>> _run<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return Ok(await action());
    } on Exception catch (error) {
      log.warning(
        'recoverbull.attempts.storage.$operation.failed error_type=${error.runtimeType}',
      );
      return const Err(
        RecoverBullUnexpectedFailure('Attempt monitoring storage failed'),
      );
    }
  }

  @override
  Future<Result<RecoverBullOwnAttemptOperation?, RecoverBullFailure>>
  beginOwnOperation(
    List<int> identifier, {
    required String password,
    required DateTime now,
  }) => _run(
    'beginOwnOperation',
    () => _store.beginOwnOperation(identifier, password: password, now: now),
  );

  @override
  Future<Result<SuspiciousActivityAlert?, RecoverBullFailure>>
  completeOwnOperation(
    RecoverBullOwnAttemptOperation operation, {
    required bool counted,
    KeyServerAttemptStatus? status,
    RecoverBullAttemptsSnapshot? snapshot,
  }) => _run(
    'completeOwnOperation',
    () => _store.completeOwnOperation(
      operation,
      counted: counted,
      status: status,
      snapshot: snapshot,
    ),
  );

  @override
  Future<Result<bool, RecoverBullFailure>> isOwnOperationCurrent(
    RecoverBullOwnAttemptOperation operation,
  ) => _run(
    'isOwnOperationCurrent',
    () => _store.isOwnOperationCurrent(operation),
  );

  @override
  Future<Result<Null, RecoverBullFailure>> endOwnOperation(
    RecoverBullOwnAttemptOperation operation,
  ) => _run('endOwnOperation', () async {
    await _store.endOwnOperation(operation);
    return null;
  });

  @override
  Future<Result<Null, RecoverBullFailure>> cancelOwnOperations() =>
      _run('cancelOwnOperations', () async {
        await _store.cancelOwnOperations();
        return null;
      });

  @override
  List<int> digestFor(List<int> identifier) => _store.digestFor(identifier);

  @override
  Future<Result<List<MonitoredBackup>, RecoverBullFailure>>
  monitoredBackups() =>
      _run('monitoredBackups', () => _store.monitoredBackups());

  @override
  Future<Result<Null, RecoverBullFailure>> replaceBackup(
    AttemptMonitoringBackupState value, {
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) => _run('replaceBackup', () async {
    await _store.replaceBackup(value, token: token);
    return null;
  });

  @override
  Future<Result<bool, RecoverBullFailure>> isMonitored(List<int> identifier) =>
      _run('isMonitored', () => _store.isMonitored(identifier));

  @override
  Future<Result<Null, RecoverBullFailure>> removeBackup(String backupIdHex) =>
      _run('removeBackup', () async {
        await _store.removeBackup(backupIdHex);
        return null;
      });

  @override
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
  }) => _run('registerBackup', () async {
    await _store.registerBackup(
      identifier,
      origin: origin,
      observedTotal: observedTotal,
      window: window,
      token: token,
      driveAccount: driveAccount,
      driveFileId: driveFileId,
      driveFileCreatedAt: driveFileCreatedAt,
      driveFileModifiedAt: driveFileModifiedAt,
    );
    return null;
  });

  @override
  Future<Result<Null, RecoverBullFailure>> purgeDriveAccount(String account) =>
      _run('purgeDriveAccount', () async {
        await _store.purgeDriveAccount(account);
        return null;
      });

  @override
  Future<Result<List<MonitoredBackup>, RecoverBullFailure>> driveBackups(
    String account,
  ) => _run('driveBackups', () => _store.driveBackups(account));

  @override
  Future<Result<List<DriveBackupCacheEntry>, RecoverBullFailure>> driveCache(
    String account,
  ) => _run('driveCache', () => _store.driveCache(account));

  @override
  Future<Result<Null, RecoverBullFailure>> saveDriveCache({
    required String account,
    required String driveFileId,
    required List<int> backupDigest,
    required DateTime createdAt,
    DateTime? modifiedAt,
  }) => _run('saveDriveCache', () async {
    await _store.saveDriveCache(
      account: account,
      driveFileId: driveFileId,
      backupDigest: backupDigest,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
    );
    return null;
  });

  @override
  Future<Result<bool, RecoverBullFailure>> reconcileDriveBackups(
    String account,
    List<DriveBackupObservation> observations,
  ) => _run(
    'reconcileDriveBackups',
    () => _store.reconcileDriveBackups(account, observations),
  );

  @override
  Future<Result<Null, RecoverBullFailure>> recordStatus(
    List<int> identifier,
    KeyServerAttemptStatus status,
  ) => _run('recordStatus', () async {
    await _store.recordStatus(identifier, status);
    return null;
  });

  @override
  Future<Result<Null, RecoverBullFailure>> recordOwnAttempt(
    List<int> identifier, {
    required int serverTotalAttempts,
    required DateTime window,
  }) => _run('recordOwnAttempt', () async {
    await _store.recordOwnAttempt(
      identifier,
      serverTotalAttempts: serverTotalAttempts,
      window: window,
    );
    return null;
  });

  @override
  Future<Result<AttemptMonitoringState, RecoverBullFailure>> state() =>
      _run('state', () => _store.state());

  @override
  Future<Result<RecoverBullAttemptMonitoringSnapshotToken, RecoverBullFailure>>
  captureToken() => _run('captureToken', () => _store.captureToken());

  @override
  Future<Result<RecoverBullAttemptMonitoringApplyResult, RecoverBullFailure>>
  applySnapshot(
    RecoverBullAttemptsSnapshot snapshot, [
    RecoverBullAttemptMonitoringSnapshotToken? token,
  ]) => _run('applySnapshot', () => _store.applySnapshot(snapshot, token));

  @override
  Future<Result<RecoverBullAttemptMonitoringApplyResult, RecoverBullFailure>>
  rebaseline(
    RecoverBullAttemptsSnapshot snapshot,
    RecoverBullAttemptMonitoringSnapshotToken token,
  ) => _run('rebaseline', () => _store.rebaseline(snapshot, token));

  @override
  Future<Result<RecoverBullPollFailureResult, RecoverBullFailure>>
  recordPollFailure({
    required DateTime now,
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) => _run(
    'recordPollFailure',
    () => _store.recordPollFailure(now: now, token: token),
  );

  @override
  Future<Result<Null, RecoverBullFailure>> recordAttemptsUnsupported({
    required DateTime until,
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) => _run('recordAttemptsUnsupported', () async {
    await _store.recordAttemptsUnsupported(until: until, token: token);
    return null;
  });

  @override
  Future<Result<Set<String>, RecoverBullFailure>>
  acknowledgedAlertIdentities() => _run(
    'acknowledgedAlertIdentities',
    () => _store.acknowledgedAlertIdentities(),
  );

  @override
  Future<Result<Null, RecoverBullFailure>> acknowledgeAlert(
    String identity, {
    required DateTime at,
  }) => _run('acknowledgeAlert', () async {
    await _store.acknowledgeAlert(identity, at: at);
    return null;
  });

  @override
  Future<Result<Null, RecoverBullFailure>> setEnabled(bool enabled) =>
      _run('setEnabled', () async {
        await _store.setEnabled(enabled);
        return null;
      });

  @override
  Future<Result<Null, RecoverBullFailure>> reset() => _run('reset', () async {
    await _store.reset();
    return null;
  });
}
