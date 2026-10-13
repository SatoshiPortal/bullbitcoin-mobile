import '../entities/attempt_monitoring_state.dart';
import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import 'package:convert/convert.dart' as convert;
import '../entities/key_server_attempts.dart';
import '../entities/attempt_alert.dart';
import '../entities/monitored_backup.dart';
import '../entities/attempt_monitoring_snapshot.dart';
import '../repositories/recoverbull_attempt_monitoring_repository.dart';
import 'check_backup_attempt_monitoring_usecase.dart';

final class RecordLocalAttemptUsecase {
  final RecoverBullAttemptMonitoringRepository store;
  final RecoverBullAttemptMonitoringRemotePort? remote;
  final DateTime Function() now;

  const RecordLocalAttemptUsecase(
    this.store, {
    this.remote,
    DateTime Function()? clock,
  }) : now = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<Result<SuspiciousActivityAlert?, RecoverBullFailure>> execute({
    required String backupIdHex,
    KeyServerAttemptStatus? attemptStatus,
  }) async {
    final enabledResult = await store.state();
    if (enabledResult case Err(:final failure)) return Err(failure);
    if (!(enabledResult as Ok<AttemptMonitoringState, RecoverBullFailure>)
        .value
        .attemptMonitoringEnabled) {
      return const Ok(null);
    }
    final identifier = convert.hex.decode(
      backupIdHex.replaceAll(RegExp(r'\s'), ''),
    );
    if (attemptStatus == null) {
      if (remote == null) return const Ok(null);
      final current = now();
      final pollTokenResult = await store.captureToken();
      if (pollTokenResult case Err(:final failure)) return Err(failure);
      final pollToken =
          (pollTokenResult
                  as Ok<
                    RecoverBullAttemptMonitoringSnapshotToken,
                    RecoverBullFailure
                  >)
              .value;
      final storageResult1 = await store.state();
      if (storageResult1 case Err(:final failure)) return Err(failure);
      if (((storageResult1 as Ok<AttemptMonitoringState, RecoverBullFailure>)
              .value)
          .attemptsUnsupportedAt(current)) {
        final pending = await _registerPendingAdoption(
          identifier,
          token: pollToken,
        );
        if (pending case Err(:final failure)) return Err(failure);
        return const Ok(null);
      }
      final digest = store.digestFor(identifier);
      RecoverBullAttemptsSnapshot? snapshot;
      try {
        snapshot = await remote!.poll(
          etag: null,
          backupDigests: [_hex(digest)],
        );
      } on Exception catch (_) {
        final pending = await _registerPendingAdoption(
          identifier,
          token: pollToken,
        );
        if (pending case Err(:final failure)) return Err(failure);
        return const Ok(null);
      }
      if (snapshot != null && snapshot.serverUnsupported) {
        final pending = await _registerPendingAdoption(
          identifier,
          token: pollToken,
        );
        if (pending case Err(:final failure)) return Err(failure);
        final storageResult2 = await store.recordAttemptsUnsupported(
          token: pollToken,
          until: current.add(
            CheckBackupAttemptMonitoringUsecase.unsupportedServerRetryAfter,
          ),
        );
        if (storageResult2 case Err(:final failure)) return Err(failure);
        return const Ok(null);
      }
      if (snapshot == null ||
          snapshot.serviceBusy ||
          snapshot.serverUnsupported) {
        final pending = await _registerPendingAdoption(
          identifier,
          token: pollToken,
        );
        if (pending case Err(:final failure)) return Err(failure);
        return const Ok(null);
      }
      final observed = snapshot.totalAttempts.entries
          .where((entry) => _same(entry.key, digest))
          .map((entry) => entry.value)
          .firstOrNull;
      if (observed == null) return const Ok(null);
      final window =
          snapshot.windowStartedAt.entries
              .where((entry) => _same(entry.key, digest))
              .map((entry) => entry.value)
              .firstOrNull ??
          snapshot.collectionStartedAt;
      final windowIdentity = attemptWindowIdentity(window);
      final storageResult3 = await store.monitoredBackups();
      if (storageResult3 case Err(:final failure)) return Err(failure);
      final existing =
          ((storageResult3 as Ok<List<MonitoredBackup>, RecoverBullFailure>)
                  .value)
              .where((candidate) => _same(candidate.digest, digest))
              .firstOrNull;
      if (existing == null) {
        final storageResult4 = await store.registerBackup(
          identifier,
          origin: MonitoredBackupOrigin.adopted,
          observedTotal: observed,
          token: pollToken,
          window: windowIdentity,
        );
        if (storageResult4 case Err(:final failure)) return Err(failure);
      } else {
        final storageResult5 = await store.replaceBackup(
          AttemptMonitoringBackupState(
            serverUrl: '',
            backupIdHash: _hex(digest),
            expectedTotalAttempts: observed,
            currentWindow: windowIdentity,
            lastWarningWindow: windowIdentity,
          ),
          token: pollToken,
        );
        if (storageResult5 case Err(:final failure)) return Err(failure);
      }
      return const Ok(null);
    }
    final digest = store.digestFor(identifier);
    final storageResult6 = await store.monitoredBackups();
    if (storageResult6 case Err(:final failure)) return Err(failure);
    final row =
        ((storageResult6 as Ok<List<MonitoredBackup>, RecoverBullFailure>)
                .value)
            .where((candidate) => _same(candidate.digest, digest))
            .firstOrNull;
    if (row == null) {
      final storageResult7 = await store.registerBackup(
        identifier,
        origin: MonitoredBackupOrigin.adopted,
        observedTotal: attemptStatus.totalAttempts,
        window: attemptWindowIdentity(attemptStatus.windowStartedAt),
      );
      if (storageResult7 case Err(:final failure)) return Err(failure);

      return const Ok(null);
    }
    final storageResult8 = await store.recordStatus(identifier, attemptStatus);
    if (storageResult8 case Err(:final failure)) return Err(failure);

    final window = attemptWindowIdentity(attemptStatus.windowStartedAt);
    final anchor = row.currentWindow == window
        ? row.expectedServerDistinctCandidateTotal
        : 0;
    if (attemptStatus.totalAttempts <= anchor + 1 ||
        row.lastWarningWindow == window) {
      return const Ok(null);
    }
    final storageResult9 = await store.replaceBackup(
      AttemptMonitoringBackupState(
        serverUrl: '',
        backupIdHash: _hex(row.digest),
        expectedTotalAttempts: attemptStatus.totalAttempts,
        currentWindow: window,
        lastWarningWindow: window,
      ),
    );
    if (storageResult9 case Err(:final failure)) return Err(failure);

    return Ok(
      SuspiciousActivityAlert(
        backupIdHash: _hex(row.digest),
        observedTotal: attemptStatus.totalAttempts,
        expectedTotal: anchor + 1,
        windowStartedAt: attemptStatus.windowStartedAt,
      ),
    );
  }

  /// Records a server lockout without treating the current counter as a
  /// baseline. The digest is the only identifier emitted in the alert.
  Future<Result<TargetedLockoutAlert?, RecoverBullFailure>>
  recordTargetedLockout({required String backupIdHex}) async {
    final enabledResult = await store.state();
    if (enabledResult case Err(:final failure)) return Err(failure);
    if (!(enabledResult as Ok<AttemptMonitoringState, RecoverBullFailure>)
        .value
        .attemptMonitoringEnabled) {
      return const Ok(null);
    }
    final identifier = convert.hex.decode(
      backupIdHex.replaceAll(RegExp(r'\s'), ''),
    );
    final digest = store.digestFor(identifier);
    final storageResult10 = await store.isMonitored(identifier);
    if (storageResult10 case Err(:final failure)) return Err(failure);
    if (!(storageResult10 as Ok<bool, RecoverBullFailure>).value) {
      final storageResult11 = await store.registerBackup(
        identifier,
        origin: MonitoredBackupOrigin.adopted,
      );
      if (storageResult11 case Err(:final failure)) return Err(failure);
    }
    final currentState = await store.state();
    if (currentState case Err(:final failure)) return Err(failure);
    if (!(currentState as Ok<AttemptMonitoringState, RecoverBullFailure>)
        .value
        .attemptMonitoringEnabled) {
      return const Ok(null);
    }
    return Ok(TargetedLockoutAlert(backupIdHash: _hex(digest)));
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<Result<Null, RecoverBullFailure>> _registerPendingAdoption(
    List<int> identifier, {
    RecoverBullAttemptMonitoringSnapshotToken? token,
  }) => store.registerBackup(
    identifier,
    origin: MonitoredBackupOrigin.adopted,
    token: token,
  );

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List<int>.generate(a.length, (i) => i).every((i) => a[i] == b[i]);
}
