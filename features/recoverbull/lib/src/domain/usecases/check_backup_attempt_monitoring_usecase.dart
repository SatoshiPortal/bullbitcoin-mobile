import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import '../entities/attempt_alert.dart';

final class CheckBackupAttemptMonitoringUsecase {
  static const snapshotFreshness = Duration(seconds: 60);
  static const identifierSaturationThreshold = 0.9;
  static const unavailabilityThreshold = Duration(days: 3);
  static const unavailabilityWarnCooldown = Duration(days: 1);
  static const minFailuresWithoutSuccess = 3;

  final RecoverBullAttemptMonitoringStore store;
  final RecoverBullAttemptMonitoringRemotePort remote;
  final DateTime Function() now;

  const CheckBackupAttemptMonitoringUsecase({
    required this.store,
    required this.remote,
    DateTime Function()? clock,
  }) : now = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  Future<List<AttemptAlert>> execute({bool forceRefresh = false}) async {
    final rows = await store.monitoredBackups();
    if (rows.isEmpty) {
      return const [];
    }
    final state = await store.state();
    final current = now();
    if (!forceRefresh &&
        state.lastSuccessfulCheckAt != null &&
        current.difference(state.lastSuccessfulCheckAt!) < snapshotFreshness) {
      return const [];
    }
    final token = await store.captureToken();
    RecoverBullAttemptsSnapshot? snapshot;
    try {
      snapshot = await remote.poll(
        etag: forceRefresh ? null : state.etag,
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
        if (_isIdentifierSaturated(snapshot))
          const ServicePressureAlert(ServicePressureKind.identifierSaturation),
        if (unavailable) const AttemptMonitoringUnavailableAlert(since: null),
      ];
    }
    final alerts = <AttemptAlert>[];
    final collection = await store.state();
    if (collection.collectionStartedAt != null &&
        RecoverBullAttemptMonitoringStore.collectionSecond(
              collection.collectionStartedAt!,
            ) !=
            RecoverBullAttemptMonitoringStore.collectionSecond(
              snapshot.collectionStartedAt,
            )) {
      final rebaselined = await store.rebaseline(snapshot, token);
      if (!rebaselined.accepted) return const [];
      return const [];
    }
    final applied = await store.applySnapshot(snapshot, token);
    if (!applied.accepted) return const [];
    if (snapshot.notModified) return const [];
    if (_isIdentifierSaturated(snapshot)) {
      alerts.add(
        const ServicePressureAlert(ServicePressureKind.identifierSaturation),
      );
    }
    final entries = {
      for (final entry in snapshot.totalAttempts.entries)
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
      alerts.add(
        SuspiciousActivityAlert(
          backupIdHash: hash,
          observedTotal: observed,
          expectedTotal: row.expectedServerDistinctCandidateTotal,
          windowStartedAt: snapshot.collectionStartedAt,
        ),
      );
    }
    return alerts;
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
