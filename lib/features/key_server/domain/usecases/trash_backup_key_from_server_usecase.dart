import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/bull_backup.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';

/// Removes a backup key from the server using the provided password and backup file
class TrashBackupKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  TrashBackupKeyFromServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({required String password, required String backupFile}) {
    try {
      if (!BullBackup.isValid(backupFile)) {
        throw const KeyServerError.invalidBackupFile();
      }

      final backup = BullBackup(backupFile: backupFile);

      return _recoverBullRepository.trashBackupKey(
        backup.id,
        password,
        backup.salt,
      );
    } catch (e) {
      log.severe('$TrashBackupKeyFromServerUsecase: $e');
      rethrow;
    }
  }
}
