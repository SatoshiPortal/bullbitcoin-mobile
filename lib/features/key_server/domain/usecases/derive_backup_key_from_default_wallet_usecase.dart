import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/data/services/backup_key_service.dart';

class DeriveBackupKeyFromDefaultWalletUsecase {
  final VaultKeyService _backupKeyService;

  DeriveBackupKeyFromDefaultWalletUsecase({
    required VaultKeyService backupKeyService,
  }) : _backupKeyService = backupKeyService;

  Future<String> execute({required EncryptedVault vault}) async {
    try {
      return await _backupKeyService.deriveVaultKeyFromDefaultSeed(
        path: vault.derivationPath,
      );
    } catch (e) {
      log.severe('$DeriveBackupKeyFromDefaultWalletUsecase: $e');
      rethrow;
    }
  }
}
