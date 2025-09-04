import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/key_server/domain/errors/key_server_error.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

/// If the key server is up
class RestoreVaultKeyFromPasswordUsecase {
  final RecoverBullRepository recoverBullRepository;

  RestoreVaultKeyFromPasswordUsecase({required this.recoverBullRepository});

  Future<String> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    try {
      final vaultKey = await recoverBullRepository.fetchVaultKey(
        vault.id,
        password,
        vault.salt,
      );

      return vaultKey;
    } on recoverbull.KeyServerException catch (e) {
      throw KeyServerError.fromException(e);
    } catch (e) {
      log.severe('$RestoreVaultKeyFromPasswordUsecase: $e');
      rethrow;
    }
  }
}
