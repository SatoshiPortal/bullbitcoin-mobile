import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
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
      if (!EncryptedVault.isValid(backupFile)) {
        throw const KeyServerError.invalidBackupFile();
      }

      final backup = EncryptedVault(backupFile: backupFile);

      return await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: backup.derivationPath,
      );
    } catch (e) {
      log.severe('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
