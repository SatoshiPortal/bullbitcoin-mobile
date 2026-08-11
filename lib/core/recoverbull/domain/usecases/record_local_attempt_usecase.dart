import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Records one of the user's own key-server operations (store/fetch/trash)
/// in the telemetry baseline, and reports whether the server's attempt
/// counters exceed this device's own operations — the suspicious-activity
/// signal.
class RecordLocalAttemptUsecase {
  final RecoverBullRepository recoverBullRepository;

  RecordLocalAttemptUsecase({required this.recoverBullRepository});

  /// [backupIdHex] is the backup identifier as hex (never persisted; only
  /// its hash is). [attemptStatus] is the server's authoritative counter set
  /// when available (null against older servers).
  ///
  /// Returns a [SuspiciousActivityAlert] when the server's total exceeds
  /// this device's own count, else null. Advisory: the excess can be an
  /// attacker OR another of the user's devices — the UI copy must say so.
  Future<Result<SuspiciousActivityAlert?, RecoverBullCoreFailure>> execute({
    required String backupIdHex,
    KeyServerAttemptStatus? attemptStatus,
  }) async {
    try {
      final serverUrl = (await recoverBullRepository.fetchUrl()).toString();
      final backupIdHash = recoverbull.attemptsIdHashFromHex(
        backupIdHex.replaceAll(RegExp(r'\s'), ''),
      );
      final existing = await recoverBullRepository.fetchTelemetryBackup(
        serverUrl,
        backupIdHash,
      );

      var expected = (existing?.expectedTotalAttempts ?? 0) + 1;
      var window = existing?.currentWindowStartedAt;

      SuspiciousActivityAlert? alert;
      var lastWarningWindow = existing?.lastWarningWindowStartedAt;
      if (attemptStatus != null) {
        // hour granularity: attempt_status is exact, the snapshot is
        // hour-truncated, and both must compare equal for the same window
        final statusWindow = telemetryWindowIdentity(
          attemptStatus.windowStartedAt,
        );
        if (window != statusWindow) {
          // this operation opened a fresh window
          expected = 1;
          window = statusWindow;
        }
        // One alert per window, same dedup as the snapshot path: without it,
        // every subsequent recovery in the same window re-raises the
        // identical alert even after the user acknowledged it.
        if (attemptStatus.totalAttempts > expected &&
            lastWarningWindow != statusWindow) {
          alert = SuspiciousActivityAlert(
            backupIdHash: backupIdHash,
            observedTotal: attemptStatus.totalAttempts,
            expectedTotal: expected,
            windowStartedAt: attemptStatus.windowStartedAt,
          );
          lastWarningWindow = statusWindow;
        }
      }

      await recoverBullRepository.upsertTelemetryBackup(
        RecoverbullTelemetryBackupRow(
          serverUrl: serverUrl,
          backupIdHash: backupIdHash,
          expectedTotalAttempts: expected,
          currentWindowStartedAt: window,
          lastWarningWindowStartedAt: lastWarningWindow,
          acknowledgedAt: existing?.acknowledgedAt,
        ),
      );

      return Ok(alert);
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
