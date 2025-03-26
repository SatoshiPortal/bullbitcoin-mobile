import 'package:bb_mobile/_core/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/key_server/domain/errors/key_server_error.dart';
import 'package:bb_mobile/recover_wallet/domain/entities/backup_info.dart';
import 'package:flutter/foundation.dart';
import 'package:recoverbull/recoverbull.dart';

/// If the key server is up
class RestoreBackupKeyFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;

  RestoreBackupKeyFromPasswordUsecase({
    required this.recoverBullRepository,
  });

  Future<String> execute({
    required String backupAsString,
    required String password,
  }) async {
    try {
      final backupInfo = BackupInfo(encrypted: backupAsString);
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
      debugPrint('$RestoreBackupKeyFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
