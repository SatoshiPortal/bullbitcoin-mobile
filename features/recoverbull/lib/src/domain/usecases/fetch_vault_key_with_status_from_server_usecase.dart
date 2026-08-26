import '../entity/encrypted_vault.dart';
import '../entity/key_server_attempts.dart';
import '../ports.dart';
import '../repositories/recoverbull_repository.dart';
import '../recoverbull_failure.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'record_local_attempt_usecase.dart';
import '../recoverbull_tor_route.dart';
import '../../support/logger.dart';

final class FetchVaultKeyWithStatusFromServerUsecase {
  final RecoverBullRepository repository;
  final EnsureRecoverBullTorSessionUsecase ensureSession;
  final RecordLocalAttemptUsecase? recordAttempt;
  final RecoverBullAttemptAlertPort? alertPort;
  const FetchVaultKeyWithStatusFromServerUsecase(
    this.repository,
    this.ensureSession, [
    this.recordAttempt,
    this.alertPort,
  ]);

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    final session = await ensureSession.execute();
    return switch (session) {
      Ok(:final value) => _fetch(vault, password, value, ownsRoute: true),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> _fetch(
    EncryptedVault vault,
    String password,
    RecoverBullTorRoute route, {
    required bool ownsRoute,
  }) async {
    try {
      final result = await repository.fetchVaultKeyWithStatus(
        vault.id,
        password,
        vault.salt,
        route,
      );
      if (result case Ok(:final value) when value.attemptStatus != null) {
        try {
          final alert = await recordAttempt?.execute(
            backupIdHex: vault.id,
            attemptStatus: value.attemptStatus,
          );
          if (alert != null) alertPort?.publish(alert);
        } catch (_) {}
      }
      return result;
    } finally {
      try {
        if (ownsRoute) await route.close();
      } catch (error, stackTrace) {
        log.warning(
          'closing the RecoverBull Tor session failed',
          error: error,
          trace: stackTrace,
        );
      }
    }
  }
}
