import 'package:bull_logger/bull_logger.dart';
import '../public/recoverbull_contracts.dart';
import '../data/recoverbull_monitoring_settings_adapter.dart';
import '../domain/usecases/load_recoverbull_monitoring_status_usecase.dart';
import '../domain/usecases/change_recoverbull_monitoring_enabled_usecase.dart';
export '../domain/usecases/load_recoverbull_monitoring_status_usecase.dart';
export '../domain/usecases/change_recoverbull_monitoring_enabled_usecase.dart';

/// Settings consumers call domain usecases while the controller stays public.
({
  LoadRecoverBullMonitoringStatusUsecase load,
  ChangeRecoverBullMonitoringEnabledUsecase change,
})
createRecoverBullMonitoringSettingsUsecases(
  RecoverBullAttemptMonitoringController controller, {
  required LogSink log,
}) {
  final port = RecoverBullMonitoringSettingsAdapter(controller, log);
  return (
    load: LoadRecoverBullMonitoringStatusUsecase(port),
    change: ChangeRecoverBullMonitoringEnabledUsecase(port),
  );
}
