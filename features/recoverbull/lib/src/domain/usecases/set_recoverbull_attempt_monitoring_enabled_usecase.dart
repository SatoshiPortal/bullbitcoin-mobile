import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import '../repositories/recoverbull_attempt_monitoring_repository.dart';

final class SetRecoverbullAttemptMonitoringEnabledUsecase {
  final RecoverBullAttemptMonitoringRepository store;
  const SetRecoverbullAttemptMonitoringEnabledUsecase(this.store);
  Future<Result<Null, RecoverBullFailure>> execute(bool enabled) =>
      store.setEnabled(enabled);
}
