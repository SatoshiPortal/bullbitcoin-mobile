import 'package:primitives/primitives.dart';
import '../entities/encrypted_vault.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import '../repositories/recoverbull_repository.dart';
import 'ensure_recoverbull_tor_session_usecase.dart';
import 'record_local_attempt_usecase.dart';
import '../ports.dart';
import '../../support/logger.dart';

final class TrashVaultKeyUsecase {
  final RecoverBullRepository repository;
  final EnsureRecoverBullTorSessionUsecase ensureSession;
  final RecordLocalAttemptUsecase? recordAttempt;
  final RecoverBullAttemptAlertPort? alertPort;

  const TrashVaultKeyUsecase(
    this.repository,
    this.ensureSession, [
    this.recordAttempt,
    this.alertPort,
  ]);

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> execute({
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

  Future<Result<VaultKeyFetchResult, RecoverBullCoreFailure>> _trash(
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
        } catch (_) {}
      }
      return result;
    } finally {
      if (ownsRoute) {
        try {
          await route.close();
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
}
