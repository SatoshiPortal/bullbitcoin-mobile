import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
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
      final backupInfo = backupFile.backupInfo;
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      return _recoverBullRepository.trashBackupKey(
        backupInfo.id,
        password,
        backupInfo.salt,
      );
    } catch (e) {
      log.severe('$TrashBackupKeyFromServerUsecase: $e');
      rethrow;
    }
  }
}
