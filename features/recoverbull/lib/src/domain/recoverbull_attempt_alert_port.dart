import 'entities/attempt_alert.dart';

abstract interface class RecoverBullAttemptAlertPort {
  void publish(AttemptAlert alert);
}
