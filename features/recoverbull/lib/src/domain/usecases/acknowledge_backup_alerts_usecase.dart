import 'package:primitives/primitives.dart';
import '../entities/backup_monitoring.dart';
import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';

final class AcknowledgeBackupAlertsUsecase {
  final AttemptMonitoringRepository _repository;
  const AcknowledgeBackupAlertsUsecase(this._repository);
  Future<Result<void, RecoverBullFailure>> execute(
    List<BackupAlert> alerts,
  ) async {
    for (final alert in alerts) {
      if (await _repository.acknowledge(alert.acknowledgement) case Err(
        :final failure,
      )) {
        return Err(failure);
      }
    }
    return const Ok(null);
  }
}
