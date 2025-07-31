import 'package:bb_mobile/core/recoverbull/domain/entity/backup_info.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/data/services/backup_key_service.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';

class DeriveBackupKeyFromDefaultWalletUsecase {
  final BackupKeyService _backupKeyService;

  DeriveBackupKeyFromDefaultWalletUsecase({
    required BackupKeyService backupKeyService,
  }) : _backupKeyService = backupKeyService;

  Future<String> execute({required String backupFile}) async {
    try {
      final backupInfo = backupFile.backupInfo;
      if (backupInfo.isCorrupted) {
        throw const KeyServerError.invalidBackupFile();
      }

      return await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: backupInfo.path,
      );
    } catch (e) {
      log.severe('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
