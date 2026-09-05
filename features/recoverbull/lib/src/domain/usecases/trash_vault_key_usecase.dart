import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import '../repositories/recoverbull_repository.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';
import 'record_local_attempt_usecase.dart';
import '../recoverbull_attempt_alert_port.dart';
import 'package:bull_logger/bull_logger.dart';

final class TrashVaultKeyUsecase {
  final LogSink log;
  final RecoverBullRepository repository;
  final EnsureRecoverBullTorSessionUsecase ensureSession;
  final RecordLocalAttemptUsecase? recordAttempt;
  final RecoverBullAttemptAlertPort? alertPort;

  const TrashVaultKeyUsecase({
    required this.repository,
    required this.ensureSession,
    this.recordAttempt,
    this.alertPort,
    required this.log,
  });

  Future<Result<VaultKeyFetchResult, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required String password,
    RecoverBullTorRoute? route,
  }) async {
    if (route != null) return _trash(vault, password, route, ownsRoute: false);
    final session = await ensureSession.execute();
    return switch (session) {
      Ok(:final value) => _trash(vault, password, value, ownsRoute: true),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<VaultKeyFetchResult, RecoverBullFailure>> _trash(
    EncryptedVault vault,
    String password,
    RecoverBullTorRoute route, {
    required bool ownsRoute,
  }) async {
    try {
      final result = await repository.trashVaultKeyWithStatus(
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
        } catch (error, _) {
          log.warning(
            'recoverbull.attempts.monitoring.update.failed '
            'error_type=${error.runtimeType}',
          );
        }
      }
      if (result case Ok()) {
        await recordAttempt?.store.removeBackup(vault.id);
      }
      return result;
    } finally {
      if (ownsRoute) {
        try {
          await route.close();
        } catch (error, _) {
          log.warning(
            'recoverbull.tor.session.close.failed error_type=${error.runtimeType}',
          );
        }
      }
    }
  }
}
