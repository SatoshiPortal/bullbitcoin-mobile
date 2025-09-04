import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';

/// Removes a backup key from the server using the provided password and backup file
class TrashBackupKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;

  TrashBackupKeyFromServerUsecase({
    required RecoverBullRepository recoverBullRepository,
  }) : _recoverBullRepository = recoverBullRepository;

  Future<void> execute({
    required String password,
    required EncryptedVault vault,
  }) {
    try {
      return _recoverBullRepository.trashVaultKey(
        vault.id,
        password,
        vault.salt,
      );
    } catch (e) {
      log.severe('$TrashBackupKeyFromServerUsecase: $e');
      rethrow;
    }
  }
}
