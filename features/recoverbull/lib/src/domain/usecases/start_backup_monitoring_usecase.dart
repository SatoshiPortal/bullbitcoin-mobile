import 'package:bull_logger/bull_logger.dart';

import 'check_backup_monitoring_usecase.dart';
import 'discover_drive_backups_usecase.dart';

/// One call from the foreground process root, independent of screen sessions.
final class StartBackupMonitoringUsecase {
  final DiscoverDriveBackupsUsecase _discover;
  final CheckBackupMonitoringUsecase _check;
  bool _started = false;
  StartBackupMonitoringUsecase(this._discover, this._check);

  Future<void> execute() async {
    if (_started) return;
    _started = true;
    log.fine('recoverbull.monitoring.start');
    // Discovery failure does not suppress checking already enrolled vaults.
    await _discover.execute();
    await _check.execute();
    log.fine('recoverbull.monitoring.finished');
  }
}
