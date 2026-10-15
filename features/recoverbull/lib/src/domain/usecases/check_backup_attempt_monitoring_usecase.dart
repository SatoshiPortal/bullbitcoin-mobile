import '../entities/attempt_monitoring_state.dart';
import '../entities/monitored_backup.dart';
import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../entities/attempt_monitoring_snapshot.dart';
import '../repositories/recoverbull_attempt_monitoring_repository.dart';
import '../entities/attempt_alert.dart';

final class CheckBackupAttemptMonitoringUsecase {
  static const snapshotFreshness = Duration(seconds: 60);
  static const identifierSaturationThreshold = 0.9;
  static const unavailabilityThreshold = Duration(days: 3);
  static const unavailabilityWarnCooldown = Duration(days: 1);
  static const minFailuresWithoutSuccess = 3;
  static const unsupportedServerRetryAfter = Duration(days: 1);

  final RecoverBullAttemptMonitoringRepository store;
  final RecoverBullAttemptMonitoringRemotePort remote;
  final DateTime Function() now;

  const CheckBackupAttemptMonitoringUsecase({
    required this.store,
    required this.remote,
    DateTime Function()? clock,
  }) : now = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<Result<List<AttemptAlert>, RecoverBullFailure>> execute({
    bool forceRefresh = false,
  }) async {
    final storageResult1 = await store.monitoredBackups();
    if (storageResult1 case Err(:final failure)) return Err(failure);
    final rows =
        (storageResult1 as Ok<List<MonitoredBackup>, RecoverBullFailure>).value;
    if (rows.isEmpty) {
      return const Ok([]);
    }
    final storageResult2 = await store.state();
    if (storageResult2 case Err(:final failure)) return Err(failure);
    final state =
        (storageResult2 as Ok<AttemptMonitoringState, RecoverBullFailure>)
            .value;
    if (!state.attemptMonitoringEnabled) return const Ok([]);
    final current = now();
    if (state.attemptsUnsupportedAt(current)) return const Ok([]);
    if (!forceRefresh &&
        state.lastSuccessfulCheckAt != null &&
        current.difference(state.lastSuccessfulCheckAt!) < snapshotFreshness) {
      return const Ok([]);
    }
    final storageResult3 = await store.captureToken();
    if (storageResult3 case Err(:final failure)) return Err(failure);
    final token =
        (storageResult3
                as Ok<
                  RecoverBullAttemptMonitoringSnapshotToken,
                  RecoverBullFailure
                >)
            .value;
    RecoverBullAttemptsSnapshot? snapshot;
    try {
      snapshot = await remote.poll(
        etag: forceRefresh ? null : state.etag,
        backupDigests: rows.map((row) => _hex(row.digest)).toList(),
      );
    } on Exception catch (_) {
      final storageResult4 = await store.recordPollFailure(
        now: current,
        token: token,
      );
      if (storageResult4 case Err(:final failure)) return Err(failure);
      final unavailable =
          (storageResult4
                  as Ok<RecoverBullPollFailureResult, RecoverBullFailure>)
              .value;
      return Ok(
        unavailable.shouldWarn
            ? [const AttemptMonitoringUnavailableAlert(since: null)]
            : const [],
      );
    }
    if (snapshot == null) {
      final storageResult5 = await store.recordPollFailure(
        now: current,
        token: token,
      );
      if (storageResult5 case Err(:final failure)) return Err(failure);
      final unavailable =
          (storageResult5
                  as Ok<RecoverBullPollFailureResult, RecoverBullFailure>)
              .value;
      return Ok(
        unavailable.shouldWarn
            ? [const AttemptMonitoringUnavailableAlert(since: null)]
            : const [],
      );
    }
    if (snapshot.serverUnsupported) {
      final storageResult6 = await store.recordAttemptsUnsupported(
        until: current.add(unsupportedServerRetryAfter),
        token: token,
      );
      if (storageResult6 case Err(:final failure)) return Err(failure);

      return const Ok([]);
    }
    if (snapshot.notModified) {
      final storageResult7 = await store.applySnapshot(snapshot, token);
      if (storageResult7 case Err(:final failure)) return Err(failure);

      return const Ok([]);
    }
    if (snapshot.serviceBusy) {
      final storageResult8 = await store.recordPollFailure(
        now: current,
        token: token,
      );
      if (storageResult8 case Err(:final failure)) return Err(failure);
      final unavailable =
          (storageResult8
                  as Ok<RecoverBullPollFailureResult, RecoverBullFailure>)
              .value;
      if (!unavailable.accepted) return const Ok([]);
      return Ok([
        const ServicePressureAlert(ServicePressureKind.serviceBusy),
        if (_isIdentifierSaturated(snapshot))
          const ServicePressureAlert(ServicePressureKind.identifierSaturation),
        if (unavailable.shouldWarn)
          const AttemptMonitoringUnavailableAlert(since: null),
      ]);
    }
    final alerts = <AttemptAlert>[];
    final collection = state;
    if (collection.isOtherCollection(snapshot.collectionStartedAt)) {
      final storageResult10 = await store.rebaseline(snapshot, token);
      if (storageResult10 case Err(:final failure)) return Err(failure);
      final rebaselined =
          (storageResult10
                  as Ok<
                    RecoverBullAttemptMonitoringApplyResult,
                    RecoverBullFailure
                  >)
              .value;
      if (!rebaselined.accepted) return const Ok([]);
      return const Ok([]);
    }
    final storageResult11 = await store.applySnapshot(snapshot, token);
    if (storageResult11 case Err(:final failure)) return Err(failure);
    final applied =
        (storageResult11
                as Ok<
                  RecoverBullAttemptMonitoringApplyResult,
                  RecoverBullFailure
                >)
            .value;
    if (!applied.accepted) return const Ok([]);
    if (snapshot.notModified) return const Ok([]);
    if (_isIdentifierSaturated(snapshot)) {
      alerts.add(
        const ServicePressureAlert(ServicePressureKind.identifierSaturation),
      );
    }
    alerts.addAll(applied.alerts);
    return Ok(alerts);
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static bool _isIdentifierSaturated(RecoverBullAttemptsSnapshot snapshot) {
    final total = snapshot.totalEntries;
    final capacity = snapshot.maxAttemptIdentifiers;
    return total != null &&
        capacity != null &&
        capacity > 0 &&
        total >= capacity * identifierSaturationThreshold;
  }
}
