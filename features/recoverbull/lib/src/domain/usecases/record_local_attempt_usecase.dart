import 'package:convert/convert.dart' as convert;
import '../entities/key_server_attempts.dart';
import '../entities/attempt_alert.dart';
import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';

final class RecordLocalAttemptUsecase {
  final RecoverBullAttemptMonitoringStore store;
  const RecordLocalAttemptUsecase(this.store);

  Future<SuspiciousActivityAlert?> execute({
    required String backupIdHex,
    KeyServerAttemptStatus? attemptStatus,
  }) async {
    if (attemptStatus == null) return null;
    final identifier = convert.hex.decode(
      backupIdHex.replaceAll(RegExp(r'\s'), ''),
    );
    final digest = store.digestFor(identifier);
    final row = (await store.monitoredBackups())
        .where((candidate) => _same(candidate.digest, digest))
        .firstOrNull;
    await store.recordStatus(identifier, attemptStatus);
    if (row == null) {
      return null;
    }
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
  static bool _same(List<int> a, List<int> b) =>
      a.length == b.length &&
      List<int>.generate(a.length, (i) => i).every((i) => a[i] == b[i]);
}
