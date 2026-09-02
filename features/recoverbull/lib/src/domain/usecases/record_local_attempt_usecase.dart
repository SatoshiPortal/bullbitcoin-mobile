import 'package:convert/convert.dart' as convert;
import '../entities/key_server_attempts.dart';
import '../entities/attempt_alert.dart';
import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';

final class RecordLocalAttemptUsecase {
  final RecoverBullAttemptMonitoringStore store;
  final RecoverBullAttemptMonitoringRemotePort? remote;

  const RecordLocalAttemptUsecase(this.store, {this.remote});

  Future<SuspiciousActivityAlert?> execute({
    required String backupIdHex,
    KeyServerAttemptStatus? attemptStatus,
  }) async {
    final identifier = convert.hex.decode(
      backupIdHex.replaceAll(RegExp(r'\s'), ''),
    );
    if (attemptStatus == null) {
      if (remote == null) return null;
      final digest = store.digestFor(identifier);
      RecoverBullAttemptsSnapshot? snapshot;
      try {
        snapshot = await remote!.poll(
          etag: null,
          backupDigests: [_hex(digest)],
        );
      } catch (_) {
        await _registerPendingAdoption(identifier);
        rethrow;
      }
      if (snapshot == null || snapshot.serviceBusy) {
        await _registerPendingAdoption(identifier);
        return null;
      }
      final observed = snapshot.totalAttempts.entries
          .where((entry) => _same(entry.key, digest))
          .map((entry) => entry.value)
          .firstOrNull;
      if (observed == null) return null;
      final window =
          snapshot.windowStartedAt.entries
              .where((entry) => _same(entry.key, digest))
              .map((entry) => entry.value)
              .firstOrNull ??
          snapshot.collectionStartedAt;
      final windowIdentity = attemptWindowIdentity(window);
      final existing = (await store.monitoredBackups())
          .where((candidate) => _same(candidate.digest, digest))
          .firstOrNull;
      if (existing == null) {
        await store.registerBackup(
          identifier,
          origin: MonitoredBackupOrigin.adopted,
          observedTotal: observed,
          window: windowIdentity,
        );
      } else {
        await store.replaceBackup(
          AttemptMonitoringBackupState(
            serverUrl: '',
            backupIdHash: _hex(digest),
            expectedTotalAttempts: observed,
            currentWindow: windowIdentity,
            lastWarningWindow: windowIdentity,
          ),
        );
      }
      return null;
    }
    final digest = store.digestFor(identifier);
    final row = (await store.monitoredBackups())
        .where((candidate) => _same(candidate.digest, digest))
        .firstOrNull;
    if (row == null) {
      await store.registerBackup(
        identifier,
        origin: MonitoredBackupOrigin.adopted,
        observedTotal: attemptStatus.totalAttempts,
        window: attemptWindowIdentity(attemptStatus.windowStartedAt),
      );
      return null;
    }
    await store.recordStatus(identifier, attemptStatus);
    final window = attemptWindowIdentity(attemptStatus.windowStartedAt);
    final anchor = row.currentWindow == window
        ? row.expectedServerDistinctCandidateTotal
        : 0;
    if (attemptStatus.totalAttempts <= anchor + 1 ||
        row.lastWarningWindow == window) {
      return null;
    }
    await store.replaceBackup(
      AttemptMonitoringBackupState(
        serverUrl: '',
        backupIdHash: _hex(row.digest),
        expectedTotalAttempts: attemptStatus.totalAttempts,
        currentWindow: window,
        lastWarningWindow: window,
      ),
    );
    return SuspiciousActivityAlert(
      backupIdHash: _hex(row.digest),
      observedTotal: attemptStatus.totalAttempts,
      expectedTotal: anchor + 1,
      windowStartedAt: attemptStatus.windowStartedAt,
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<void> _registerPendingAdoption(List<int> identifier) =>
      store.registerBackup(identifier, origin: MonitoredBackupOrigin.adopted);

  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List<int>.generate(a.length, (i) => i).every((i) => a[i] == b[i]);
}
