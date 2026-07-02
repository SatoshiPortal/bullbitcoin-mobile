import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

class FetchVaultKeyFromServerUsecase {
  final RecoverBullRepository recoverBullRepository;

  FetchVaultKeyFromServerUsecase({required this.recoverBullRepository});

  Future<Result<String, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) {
    return recoverBullRepository.fetchVaultKey(vault.id, password, vault.salt);
  }
}
