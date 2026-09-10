import 'package:convert/convert.dart' as convert;
import '../../attempt_monitoring/recoverbull_attempt_monitoring.dart';

final class RegisterMonitoredBackupUsecase {
  final RecoverBullAttemptMonitoringStore store;
  const RegisterMonitoredBackupUsecase(this.store);

  Future<void> execute({required String backupIdHex}) => store.registerBackup(
    convert.hex.decode(backupIdHex.replaceAll(RegExp(r'\s'), '')),
  );
}
