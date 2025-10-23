import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/vault_key_service.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/recoverbull/domain/errors/key_server_error.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Stores a backup key on the server with password protection
class StoreVaultKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final VaultKeyService _backupKeyService;

  StoreVaultKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
    required VaultKeyService backupService,
  }) : _recoverBullRepository = recoverBullRepository,
       _backupKeyService = backupService;

  Future<void> execute({
    required String password,
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    try {
      final derivedKey = await _backupKeyService.deriveVaultKeyFromDefaultSeed(
        path: vault.derivationPath,
      );

      if (vaultKey != derivedKey) throw KeyServerError.keyMismatch();

      await _recoverBullRepository.storeVaultKey(
        vault.id,
        password,
        vault.salt,
        vaultKey,
      );
    } on recoverbull.KeyServerException catch (e) {
      log.severe('$StoreVaultKeyIntoServerUsecase: $e');
      throw KeyServerError.fromException(e);
    } catch (e) {
      if (e is! KeyServerError) {
        log.severe('$StoreVaultKeyIntoServerUsecase: $e');
      }
      rethrow;
    }
  }
}
