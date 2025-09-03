import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/data/services/backup_key_service.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart'
    show KeyServerError;
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Stores a backup key on the server with password protection
class StoreBackupKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final BackupKeyService _backupKeyService;

  StoreBackupKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
    required BackupKeyService backupService,
  }) : _recoverBullRepository = recoverBullRepository,
       _backupKeyService = backupService;

  Future<void> execute({
    required String password,
    required String backupFile,
    required String backupKey,
  }) async {
    try {
      if (!EncryptedVault.isValid(backupFile)) {
        throw const KeyServerError.invalidBackupFile();
      }

      final vault = EncryptedVault(file: backupFile);

      final derivedKey = await _backupKeyService.deriveBackupKeyFromDefaultSeed(
        path: vault.derivationPath,
      );

      if (backupKey != derivedKey) {
        throw const KeyServerError.keyMismatch();
      }

      await _recoverBullRepository.storeBackupKey(
        vault.id,
        password,
        vault.salt,
        backupKey,
      );
    } on recoverbull.KeyServerException catch (e) {
      log.severe('$StoreBackupKeyIntoServerUsecase: $e');
      throw KeyServerError.fromException(e);
    } catch (e) {
      if (e is! KeyServerError) {
        log.severe('$StoreBackupKeyIntoServerUsecase: $e');
      }
      rethrow;
    }
  }
}
