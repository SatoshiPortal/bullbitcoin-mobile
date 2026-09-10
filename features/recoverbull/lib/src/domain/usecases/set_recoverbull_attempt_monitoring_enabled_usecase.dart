import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';

final class SetRecoverbullAttemptMonitoringEnabledUsecase {
  final RecoverBullAttemptMonitoringStore store;
  const SetRecoverbullAttemptMonitoringEnabledUsecase(this.store);
  Future<void> execute(bool enabled) => store.setEnabled(enabled);
}
