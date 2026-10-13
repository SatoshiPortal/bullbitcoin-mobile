import 'package:primitives/primitives.dart';
import '../recoverbull_failure.dart';
import 'package:convert/convert.dart' as convert;
import '../repositories/recoverbull_attempt_monitoring_repository.dart';

final class RegisterMonitoredBackupUsecase {
  final RecoverBullAttemptMonitoringRepository store;
  const RegisterMonitoredBackupUsecase(this.store);

  Future<Result<Null, RecoverBullFailure>> execute({
    required String backupIdHex,
  }) => store.registerBackup(
    convert.hex.decode(backupIdHex.replaceAll(RegExp(r'\s'), '')),
  );
}
