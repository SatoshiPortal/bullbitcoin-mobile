import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Fetches a vault key from the server with the identifier's exact attempt
/// counters — the freshest telemetry signal, available even when `/attempts`
/// is overloaded.
class FetchVaultKeyWithStatusFromServerUsecase {
  final RecoverBullRepository recoverBullRepository;

  FetchVaultKeyWithStatusFromServerUsecase({
    required this.recoverBullRepository,
  });

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) {
    return recoverBullRepository.fetchVaultKeyWithStatus(
      vault.id,
      password,
      vault.salt,
    );
  }
}
