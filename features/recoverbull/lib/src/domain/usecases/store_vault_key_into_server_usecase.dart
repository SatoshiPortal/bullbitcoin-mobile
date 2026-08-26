import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';

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
    RecoverBullTorRoute? route,
  }) async {
    if (route != null) {
      return _store(password, vault, vaultKey, route, ownsRoute: false);
    }
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _store(
        password,
        vault,
        vaultKey,
        value,
        ownsRoute: true,
      ),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<Null, RecoverBullCoreFailure>> _store(
    String password,
    EncryptedVault vault,
    String vaultKey,
    RecoverBullTorRoute session, {
    required bool ownsRoute,
  }) async {
    try {
      final result = await _recoverBullRepository.storeVaultKey(
        vault.id,
        password,
        vault.salt,
        vaultKey,
        session,
      );
      return result;
    } finally {
      // A throw here would escape after the key was already stored, leaving the
      // flow half-completed with no typed failure for the caller to act on.
      try {
        if (ownsRoute) await session.close();
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
