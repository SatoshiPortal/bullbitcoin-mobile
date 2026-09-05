import '../entities/encrypted_vault.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_attempt_alert_port.dart';
import '../repositories/recoverbull_repository.dart';
import '../recoverbull_failure.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';
import 'package:primitives/primitives.dart';
import 'record_local_attempt_usecase.dart';
import '../recoverbull_tor_route.dart';
import 'package:bull_logger/bull_logger.dart';

final class FetchVaultKeyWithStatusFromServerUsecase {
  final LogSink log;
  final RecoverBullRepository repository;
  final EnsureRecoverBullTorSessionUsecase ensureSession;
  final RecordLocalAttemptUsecase? recordAttempt;
  final RecoverBullAttemptAlertPort? alertPort;
  const FetchVaultKeyWithStatusFromServerUsecase({
    required this.repository,
    required this.ensureSession,
    this.recordAttempt,
    this.alertPort,
    required this.log,
  });

  Future<Result<VaultKeyFetchResult, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required String password,
  }) async {
    final session = await ensureSession.execute();
    return switch (session) {
      Ok(:final value) => _fetch(vault, password, value, ownsRoute: true),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<VaultKeyFetchResult, RecoverBullFailure>> _fetch(
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
      switch (result) {
        case Ok(:final value):
          try {
            final alert = await recordAttempt?.execute(
              backupIdHex: vault.id,
              attemptStatus: value.attemptStatus,
            );
            if (alert != null) alertPort?.publish(alert);
          } catch (error, _) {
            log.warning(
              'recoverbull.attempts.monitoring.update.failed '
              'error_type=${error.runtimeType}',
            );
          }
        case Err(:final failure) when failure is KeyServerRateLimitedFailure:
          try {
            final alert = await recordAttempt?.recordTargetedLockout(
              backupIdHex: vault.id,
            );
            if (alert != null) alertPort?.publish(alert);
          } catch (error, _) {
            log.warning(
              'recoverbull.attempts.monitoring.update.failed '
              'error_type=${error.runtimeType}',
            );
          }
        case Err():
      }
      return result;
    } finally {
      try {
        if (ownsRoute) await route.close();
      } catch (error, _) {
        log.warning(
          'recoverbull.tor.session.close.failed error_type=${error.runtimeType}',
        );
      }
    }
  }
}
