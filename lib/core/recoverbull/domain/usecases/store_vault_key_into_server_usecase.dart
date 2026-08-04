import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';

/// Stores a backup key on the server with password protection
class StoreVaultKeyIntoServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  StoreVaultKeyIntoServerUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase,
  );

  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required String password,
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _store(password, vault, vaultKey, value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Null, RecoverBullCoreFailure>> _store(
    String password,
    EncryptedVault vault,
    String vaultKey,
    RecoverBullTorRoute session,
  ) async {
    try {
      return await _recoverBullRepository.storeVaultKey(
        vault.id,
        password,
        vault.salt,
        vaultKey,
        session.endpoint,
      );
    } finally {
      // A throw here would escape after the key was already stored, leaving the
      // flow half-completed with no typed failure for the caller to act on.
      try {
        await session.close();
      } catch (e, st) {
        log.warning(
          'closing the RecoverBull Tor session failed',
          error: e,
          trace: st,
        );
      }
    }
  }
}
