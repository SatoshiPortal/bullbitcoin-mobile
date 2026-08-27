import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Records that the user acknowledged a telemetry alert for a backup.
/// Acknowledgement is remembered so multi-device false positives do not
/// train the user to ignore alerts.
class AcknowledgeTelemetryAlertUsecase {
  final RecoverBullRepository recoverBullRepository;

  AcknowledgeTelemetryAlertUsecase({required this.recoverBullRepository});

  Future<Result<void, RecoverBullCoreFailure>> execute({
    required String backupIdHash,
  }) async {
    try {
      final serverUrl = (await recoverBullRepository.fetchUrl()).toString();
      final existing = await recoverBullRepository.fetchTelemetryBackup(
        serverUrl,
        backupIdHash,
      );
      if (existing == null) return const Ok(null);

      await recoverBullRepository.upsertTelemetryBackup(
        existing.copyWith(acknowledgedAt: DateTime.now()),
      );
      return const Ok(null);
    } catch (e) {
      return Err(RecoverBullUnexpectedCoreFailure(e.toString()));
    }
  }
}
