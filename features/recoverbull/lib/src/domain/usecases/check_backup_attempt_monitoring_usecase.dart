import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../entities/key_server_attempts.dart';
import '../entities/attempt_alert.dart';

final class CheckBackupAttemptMonitoringUsecase {
  static const snapshotFreshness = Duration(seconds: 60);
  static const unavailabilityThreshold = Duration(days: 3);
  static const unavailabilityWarnCooldown = Duration(days: 1);
  static const minFailuresWithoutSuccess = 3;
  static const mapFullnessThreshold = .85;

  final RecoverBullAttemptMonitoringStore store;
  final RecoverBullAttemptMonitoringRemotePort remote;
  final DateTime Function() now;

  const CheckBackupAttemptMonitoringUsecase({
    required this.store,
    required this.remote,
    DateTime Function()? clock,
  }) : now = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<List<AttemptAlert>> execute() async {
    final rows = await store.monitoredBackups();
    if (rows.isEmpty) {
      return const [];
    }
    final state = await store.state();
    final current = now();
    if (state.lastSuccessfulCheckAt != null &&
        current.difference(state.lastSuccessfulCheckAt!) < snapshotFreshness) {
      return const [];
    }
    final token = await store.captureToken();
    RecoverBullAttemptsSnapshot? snapshot;
    try {
      snapshot = await remote.poll(
        etag: state.etag,
        backupDigests: rows.map((row) => _hex(row.digest)).toList(),
      );
    } catch (_) {
      final unavailable = await store.recordPollFailure(now: current);
      return unavailable
          ? [const AttemptMonitoringUnavailableAlert(since: null)]
          : const [];
    }
    if (snapshot == null) {
      final unavailable = await store.recordPollFailure(now: current);
      return unavailable
          ? [const AttemptMonitoringUnavailableAlert(since: null)]
          : const [];
    }
    if (snapshot.notModified) {
      await store.applySnapshot(snapshot, token);
      return const [];
    }
    if (snapshot.serviceBusy) {
      final unavailable = await store.recordPollFailure(now: current);
      return [
        const ServicePressureAlert(ServicePressureKind.serviceBusy),
        if (unavailable) const AttemptMonitoringUnavailableAlert(since: null),
      ];
    }
    if (snapshot.targetedLockouts.isNotEmpty) {
      return [
        for (final digest in snapshot.targetedLockouts)
          TargetedLockoutAlert(backupIdHash: _hex(digest)),
      ];
    }
    final alerts = <AttemptAlert>[];
    final collection = await store.state();
    var wiped = false;
    if (collection.collectionStartedAt != null &&
        RecoverBullAttemptMonitoringStore.collectionSecond(
              collection.collectionStartedAt!,
            ) !=
            RecoverBullAttemptMonitoringStore.collectionSecond(
              snapshot.collectionStartedAt,
            )) {
      final rebaselined = await store.rebaseline(snapshot, token);
      if (!rebaselined.accepted) return const [];
      alerts.add(CountersWipedAlert(wipedAt: snapshot.collectionStartedAt));
      wiped = true;
    }
    if (!wiped) {
      final applied = await store.applySnapshot(snapshot, token);
      if (!applied.accepted) return const [];
    }
    if (snapshot.notModified) {
      if (wiped) await store.applySnapshot(snapshot);
      return alerts;
    }
    if (wiped) return alerts;
    if (snapshot.maxAttemptIdentifiers case final max?
        when max > 0 &&
            snapshot.totalEntries != null &&
            snapshot.totalEntries! >= max * mapFullnessThreshold) {
      alerts.add(const ServicePressureAlert(ServicePressureKind.mapNearlyFull));
    }
    final entries = {
      for (final entry in snapshot.totalAttempts.entries)
        _hex(entry.key): entry.value,
    };
    final windows = {
      for (final entry in snapshot.windowStartedAt.entries)
        _hex(entry.key): entry.value,
    };
    for (final row in rows) {
      if (row.currentWindow == 0 && row.lastWarningWindow == 0) continue;
      final hash = _hex(row.digest);
      final observed = entries[hash];
      if (observed == null ||
          observed <= row.expectedServerDistinctCandidateTotal) {
        continue;
      }
      final window = attemptWindowIdentity(
        windows[hash] ?? snapshot.collectionStartedAt,
      );
      if (row.lastWarningWindow != window) {
        alerts.add(
          SuspiciousActivityAlert(
            backupIdHash: hash,
            observedTotal: observed,
            expectedTotal: row.expectedServerDistinctCandidateTotal,
            windowStartedAt: snapshot.collectionStartedAt,
          ),
        );
        await store.replaceBackup(
          AttemptMonitoringBackupState(
            serverUrl: '',
            backupIdHash: hash,
            expectedTotalAttempts: row.expectedServerDistinctCandidateTotal,
            currentWindow: row.currentWindow,
            lastWarningWindow: window,
          ),
        );
      }
    }
    return alerts;
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
