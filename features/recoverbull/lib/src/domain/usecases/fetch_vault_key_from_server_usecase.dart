import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/entity/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:primitives/primitives.dart';
import 'record_local_attempt_usecase.dart';
import '../entity/key_server_attempts.dart';
import '../ports.dart';

class FetchVaultKeyFromServerUsecase {
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;
  final RecordLocalAttemptUsecase? _recordAttempt;
  final RecoverBullAttemptAlertPort? _alertPort;

  FetchVaultKeyFromServerUsecase(
    this._recoverBullRepository,
    this._ensureTorSessionUsecase, [
    RecordLocalAttemptUsecase? recordAttempt,
    RecoverBullAttemptAlertPort? alertPort,
  ]) : _recordAttempt = recordAttempt,
       _alertPort = alertPort;

  Future<Result<String, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
    RecoverBullTorRoute? route,
  }) async {
    if (route != null) return _fetch(vault, password, route, ownsRoute: false);
    final session = await _ensureTorSessionUsecase.execute();
    return switch (session) {
      Ok(:final value) => _fetch(vault, password, value, ownsRoute: true),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<String, RecoverBullCoreFailure>> _fetch(
    EncryptedVault vault,
    String password,
    RecoverBullTorRoute session, {
    required bool ownsRoute,
  }) async {
    try {
      final result = await _recoverBullRepository.fetchVaultKeyWithStatus(
        vault.id,
        password,
        vault.salt,
        session,
      );
      return switch (result) {
        Ok(:final value) => _recordAndReturn(vault, value),
        Err(:final failure) => Err(failure),
      };
    } finally {
      // Closing forwards to a native session stop, which can throw. Letting it
      // escape a `finally` would break the `Result` contract and, worse, discard
      // a vault key this call already retrieved.
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

  Future<Result<String, RecoverBullCoreFailure>> _recordAndReturn(
    EncryptedVault vault,
    VaultKeyFetchResult value,
  ) async {
    if (value.attemptStatus != null) {
      try {
        final alert = await _recordAttempt?.execute(
          backupIdHex: vault.id,
          attemptStatus: value.attemptStatus,
        );
        if (alert != null) _alertPort?.publish(alert);
      } catch (_) {}
    }
    return Ok(value.vaultKey);
  }
}
