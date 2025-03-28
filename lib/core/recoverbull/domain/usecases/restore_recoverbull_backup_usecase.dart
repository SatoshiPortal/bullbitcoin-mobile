import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';

class RestoreRecoverBullBackupUsecase {
  final RecoverBullRepository _repository;

  RestoreRecoverBullBackupUsecase({required RecoverBullRepository repository})
      : _repository = repository;

  Future<void> execute(String backupFile, String backupKey) async {
    _repository.restoreBackupFile(backupFile, backupKey);
  }
}
