import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
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

      var expected = existing?.expectedTotalAttempts ?? 0;
      var window = existing?.currentWindow;

      SuspiciousActivityAlert? alert;
      var lastWarningWindow = existing?.lastWarningWindow;
      if (attemptStatus != null) {
        // hour granularity: attempt_status is exact, the snapshot is
        // hour-truncated, and both must compare equal for the same window
        final statusWindow = telemetryWindowIdentity(
          attemptStatus.windowStartedAt,
        );
        // The anchor is the server's own total as of this device's previous
        // operation in this window; a fresh window starts from nothing.
        final anchor = window == statusWindow ? expected : 0;
        // The server counts DISTINCT authentication candidates, not requests,
        // so this operation contributed at most ONE new candidate — none at
        // all if the user replayed a password already tried in this window.
        // Anything beyond that one is foreign: an attacker, or another of the
        // user's devices, which the copy must not conflate.
        //
        // The slack of one is the price of not knowing whether our own
        // candidate was new. It is bounded and self-correcting: the baseline
        // below re-anchors on the authoritative total, so a candidate that
        // lands after this operation is caught by the next snapshot poll,
        // which compares with no slack at all.
        final foreign = attemptStatus.totalAttempts - anchor - 1;
        // One alert per window, same dedup as the snapshot path: without it,
        // every subsequent recovery in the same window re-raises the
        // identical alert even after the user acknowledged it.
        if (foreign > 0 && lastWarningWindow != statusWindow) {
          alert = SuspiciousActivityAlert(
            backupIdHash: backupIdHash,
            observedTotal: attemptStatus.totalAttempts,
            expectedTotal: anchor + 1,
            windowStartedAt: attemptStatus.windowStartedAt,
          );
          lastWarningWindow = statusWindow;
        }
        // Re-anchor on the server's authoritative count — never a local
        // increment, which would drift above the server's total on every
        // replay and silently absorb an attacker's candidates.
        expected = attemptStatus.totalAttempts;
        window = statusWindow;
      } else {
        // Older server with no attempt_status: nothing authoritative to
        // anchor on, so fall back to counting this device's operation.
        expected = expected + 1;
      }

      await recoverBullRepository.upsertTelemetryBackup(
        TelemetryBackupState(
          serverUrl: serverUrl,
          backupIdHash: backupIdHash,
          expectedTotalAttempts: expected,
          currentWindow: window,
          lastWarningWindow: lastWarningWindow,
          acknowledgedAt: existing?.acknowledgedAt,
        ),
      );

      return Ok(alert);
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
