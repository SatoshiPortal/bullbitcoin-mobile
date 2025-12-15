import 'package:bb_mobile/core_deprecated/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core_deprecated/recoverbull/errors.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class FetchVaultKeyFromServerUsecase {
  final RecoverBullRepository recoverBullRepository;

  FetchVaultKeyFromServerUsecase({required this.recoverBullRepository});

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
      throw ServerError.fromException(e);
    } catch (e) {
      rethrow;
    }
  }
}
