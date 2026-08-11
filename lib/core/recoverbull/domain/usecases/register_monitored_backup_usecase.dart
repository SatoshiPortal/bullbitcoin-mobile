import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Registers a backup as monitored by the telemetry checks, WITHOUT counting
/// an attempt.
///
/// `/store` is deliberately not counted: the server never adds a store to its
/// rate-limit map, so it never appears in `/attempts` nor in
/// `attempt_status`. Counting it locally would inflate this device's expected
/// total by one and silently mask one real attacker probe per window (a third
/// of the attacker's budget). Pinned server-side by
/// `test_store_is_not_counted_in_attempts`.
class RegisterMonitoredBackupUsecase {
  final RecoverBullRepository recoverBullRepository;

  RegisterMonitoredBackupUsecase({required this.recoverBullRepository});

  /// [backupIdHex] is the backup identifier as hex (never persisted; only its
  /// hash is). An existing baseline is left untouched.
  Future<Result<void, RecoverBullCoreFailure>> execute({
    required String backupIdHex,
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
      if (existing != null) return const Ok(null);

      await recoverBullRepository.upsertTelemetryBackup(
        RecoverbullTelemetryBackupRow(
          serverUrl: serverUrl,
          backupIdHash: backupIdHash,
          expectedTotalAttempts: 0,
        ),
      );
      return const Ok(null);
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
