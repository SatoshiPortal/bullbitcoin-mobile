import 'package:primitives/primitives.dart';

import '../entities/backup_monitoring.dart';
import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';

final class WatchBackupMonitoringUsecase {
  final AttemptMonitoringRepository _repository;
  const WatchBackupMonitoringUsecase(this._repository);
  Stream<Result<BackupMonitoring, RecoverBullFailure>> execute() =>
      _repository.watchStatus();
}
