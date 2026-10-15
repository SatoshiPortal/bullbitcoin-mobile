import 'entities/recoverbull_attempt_alert.dart';
import 'entities/recoverbull_monitoring_status.dart';

abstract interface class RecoverBullAttemptMonitoringController {
  Future<List<RecoverBullAttemptAlert>> check();
  Future<List<RecoverBullAttemptAlert>> checkOnForeground();
  Future<void> setEnabled(bool enabled);
  Future<void> acknowledge(RecoverBullAttemptAlert alert);
  bool get enabled;
  Stream<List<RecoverBullAttemptAlert>> get alerts;
  Future<RecoverBullMonitoringStatus> status();
}
