import 'package:primitives/primitives.dart';
import '../entities/recoverbull_monitoring_status.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_monitoring_settings_port.dart';

final class LoadRecoverBullMonitoringStatusUsecase {
  final RecoverBullMonitoringSettingsPort _port;

  const LoadRecoverBullMonitoringStatusUsecase(this._port);

  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> execute() =>
      _port.status();
}
