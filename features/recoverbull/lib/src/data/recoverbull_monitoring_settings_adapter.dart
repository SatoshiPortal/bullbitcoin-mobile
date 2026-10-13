import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import '../domain/entities/recoverbull_monitoring_status.dart';
import '../domain/recoverbull_attempt_monitoring_controller.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/recoverbull_monitoring_settings_port.dart';
import '../domain/recoverbull_attempt_monitoring.dart';

final class RecoverBullMonitoringSettingsAdapter
    implements RecoverBullMonitoringSettingsPort {
  final RecoverBullAttemptMonitoringController controller;
  final LogSink log;

  const RecoverBullMonitoringSettingsAdapter(this.controller, this.log);

  @override
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>>
  status() async {
    if (controller case RecoverBullAttemptMonitoring monitor) {
      return monitor.statusResult();
    }
    try {
      return Ok(await controller.status());
    } on Exception catch (error) {
      log.warning(
        'recoverbull.monitoring.settings.load_failed error_type=${error.runtimeType}',
      );
      return const Err(
        RecoverBullUnexpectedFailure('Monitoring settings unavailable'),
      );
    }
  }

  @override
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> setEnabled(
    bool enabled,
  ) async {
    if (controller case RecoverBullAttemptMonitoring monitor) {
      return monitor.setEnabledResult(enabled);
    }
    try {
      await controller.setEnabled(enabled);
      return status();
    } on Exception catch (error) {
      log.warning(
        'recoverbull.monitoring.settings.save_failed error_type=${error.runtimeType}',
      );
      return const Err(
        RecoverBullUnexpectedFailure('Monitoring settings unavailable'),
      );
    }
  }
}
