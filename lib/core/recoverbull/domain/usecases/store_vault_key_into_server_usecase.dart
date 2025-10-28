import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/errors.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// Stores a backup key on the server with password protection
class StoreVaultKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  StoreVaultKeyIntoServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String password,
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    try {
      await _recoverBullRepository.storeVaultKey(
        vault.id,
        password,
        vault.salt,
        vaultKey,
      );
    } on recoverbull.KeyServerException catch (e) {
      log.severe('$StoreVaultKeyIntoServerUsecase: $e');
      throw ServerError.fromException(e);
    } catch (e) {
      if (e is! ServerError) {
        log.severe('$StoreVaultKeyIntoServerUsecase: $e');
      }
      rethrow;
    }
  }
}
