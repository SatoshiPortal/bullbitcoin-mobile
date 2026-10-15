import 'package:primitives/primitives.dart';
import 'entities/recoverbull_monitoring_status.dart';
import 'recoverbull_failure.dart';

abstract interface class RecoverBullMonitoringSettingsPort {
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> status();
  Future<Result<RecoverBullMonitoringStatus, RecoverBullFailure>> setEnabled(
    bool enabled,
  );
}
