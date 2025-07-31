import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:recoverbull/recoverbull.dart';

/// If the key server is up
class RestoreBackupKeyFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;

  RestoreBackupKeyFromPasswordUsecase({required this.recoverBullRepository});

  Future<String> execute({
    required String backupFile,
    required String password,
  }) async {
    try {
      final backupInfo = backupFile.backupInfo;
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      final backupKey = await recoverBullRepository.fetchBackupKey(
        backupInfo.id,
        password,
        backupInfo.salt,
      );

      return backupKey;
    } on KeyServerException catch (e) {
      throw KeyServerError.fromException(e);
    } catch (e) {
      log.severe('$RestoreBackupKeyFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
