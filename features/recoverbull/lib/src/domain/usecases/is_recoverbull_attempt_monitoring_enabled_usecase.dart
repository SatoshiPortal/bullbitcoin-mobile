import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_attempt_monitoring_repository.dart';

final class IsRecoverbullAttemptMonitoringEnabledUsecase {
  final RecoverBullAttemptMonitoringRepository store;
  const IsRecoverbullAttemptMonitoringEnabledUsecase(this.store);
  Future<Result<bool, RecoverBullFailure>> execute() async =>
      (await store.state()).map((state) => state.attemptMonitoringEnabled);
}
