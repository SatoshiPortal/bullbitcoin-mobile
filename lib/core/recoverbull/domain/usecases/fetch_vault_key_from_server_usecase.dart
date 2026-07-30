import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:tor/tor.dart';

class FetchVaultKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  FetchVaultKeyFromServerUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase,
  );

  Future<Result<String, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _fetch(vault, password, value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<String, RecoverBullCoreFailure>> _fetch(
    EncryptedVault vault,
    String password,
    TorSession session,
  ) async {
    try {
      return await _recoverBullRepository.fetchVaultKey(
        vault.id,
        password,
        vault.salt,
        session.endpoint,
      );
    } finally {
      await session.close();
    }
  }
}
