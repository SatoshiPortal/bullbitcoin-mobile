import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';

/// Fetches a vault key from the server with the identifier's exact attempt
/// counters — the freshest telemetry signal, and the only one still available
/// when `/attempts` is rate limited.
class FetchVaultKeyWithStatusFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  FetchVaultKeyWithStatusFromServerUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase,
  );

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _fetch(vault, password, value),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> _fetch(
    EncryptedVault vault,
    String password,
    RecoverBullTorRoute session,
  ) async {
    try {
      return await _recoverBullRepository.fetchVaultKeyWithStatus(
        vault.id,
        password,
        vault.salt,
        session.endpoint,
      );
    } finally {
      // Closing forwards to a native session stop, which can throw. Letting it
      // escape a `finally` would break the `Result` contract and, worse, discard
      // a vault key this call already retrieved.
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
