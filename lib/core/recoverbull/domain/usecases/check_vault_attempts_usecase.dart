import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_attempts.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_tor_route.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';

/// Reads how many wrong PINs or passwords the key server saw for a vault.
///
/// The server cannot warn anyone: a brute-force on a stolen backup file is
/// visible only in its public attempts snapshot. Advisory: a failure means
/// "unknown", never "quiet", and the caller must not block on it.
class CheckVaultAttemptsUsecase {
  /// How many times the snapshot is requested before giving up.
  static const int maxAttempts = 3;

  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;

  /// Injected so a test does not have to spend the backoff in real time.
  final Future<void> Function(Duration) _wait;

  CheckVaultAttemptsUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase, {
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  /// Borrows [route] when the flow already verified one; it stays open.
  Future<Result<VaultAttempts, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    RecoverBullTorRoute? route,
  }) async {
    if (route != null) return _check(vault, route, ownsRoute: false);
    return switch (await _ensureTorSessionUsecase.execute()) {
      Ok(:final value) => _check(vault, value, ownsRoute: true),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<VaultAttempts, RecoverBullCoreFailure>> _check(
    EncryptedVault vault,
    RecoverBullTorRoute session, {
    required bool ownsRoute,
  }) async {
    try {
      // A fresh Tor session often fails its first onion connection.
      for (var attempt = 1; ; attempt++) {
        final result = await _recoverBullRepository.fetchVaultAttempts(
          vault.id,
          session.endpoint,
        );
        if (result case Err(
          failure: KeyServerUnavailableFailure(),
        ) when attempt < maxAttempts) {
          await _wait(Duration(seconds: attempt));
          continue;
        }
        return result;
      }
    } finally {
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
