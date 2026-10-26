import 'package:primitives/primitives.dart';
import '../entities/recoverbull_monitoring_status.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_monitoring_settings_port.dart';

final class ChangeRecoverBullMonitoringEnabledUsecase {
  final RecoverBullMonitoringSettingsPort _port;

  const ChangeRecoverBullMonitoringEnabledUsecase(this._port);

  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> execute(
    bool enabled,
  ) => _port.setEnabled(enabled);
}
