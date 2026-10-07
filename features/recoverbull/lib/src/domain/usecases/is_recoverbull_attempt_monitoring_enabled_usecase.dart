import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';

final class IsRecoverbullAttemptMonitoringEnabledUsecase {
  final RecoverBullAttemptMonitoringStore store;
  const IsRecoverbullAttemptMonitoringEnabledUsecase(this.store);
  Future<bool> execute() async =>
      (await store.state()).attemptMonitoringEnabled;
}
