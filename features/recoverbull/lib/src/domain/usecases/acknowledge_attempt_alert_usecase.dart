import '../entity/recoverbull_attempt_alert.dart';

/// Alert handles are deliberately ephemeral; acknowledgement has no durable
/// timestamp and therefore cannot expose a digest or server URL.
final class AcknowledgeAttemptAlertUsecase {
  const AcknowledgeAttemptAlertUsecase();
  Future<void> execute(RecoverbullAttemptAlert alert) async {}
}
