import 'dart:async';
import '../entities/attempt_monitoring_snapshot.dart';
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
    final started = await recordAttempt?.beginOwnOperation(
      backupIdHex: vault.id,
      password: password,
    );
    final operation =
        started is Ok<RecoverBullOwnAttemptOperation?, RecoverBullFailure>
        ? started.value
        : null;
    var delegatedCompletion = false;
    try {
      final result = await repository.trashVaultKeyWithStatus(
        vault.id,
        password,
        vault.salt,
        route,
      );
      if (result case Err(failure: KeyServerInvalidCredentialsFailure())) {
        if (operation != null) {
          delegatedCompletion = true;
          unawaited(_recordRejectedAttempt(operation));
        }
      }
      switch (result) {
        case Err(:final failure) when failure is KeyServerRateLimitedFailure:
          try {
            final alert = await recordAttempt?.recordTargetedLockout(
              backupIdHex: vault.id,
              operation: operation,
            );
            if (alert case Ok(value: final value?)) alertPort?.publish(value);
          } on Exception catch (error, _) {
            log.warning(
              'recoverbull.attempts.monitoring.update.failed '
              'error_type=${error.runtimeType}',
            );
          }
        case Ok():
        case Err():
      }
      if (result case Ok()) {
        // The server already deleted the key: forgetting the backup locally is
        // advisory and must not turn that outcome into an exception.
        try {
          final removed = await recordAttempt?.store.removeBackup(vault.id);
          if (removed case Err()) {
            log.warning('recoverbull.attempts.monitoring.remove.failed');
          }
        } on Exception catch (error, _) {
          log.warning(
            'recoverbull.attempts.monitoring.remove.failed '
            'error_type=${error.runtimeType}',
          );
        }
      }
      return result;
    } finally {
      if (!delegatedCompletion && operation != null) {
        await recordAttempt?.endOwnOperation(operation);
      }
      if (ownsRoute) {
        try {
          await route.close();
        } on Exception catch (error, _) {
          log.warning(
            'recoverbull.tor.session.close.failed error_type=${error.runtimeType}',
          );
        }
      }
    }
  }

  Future<void> _recordRejectedAttempt(
    RecoverBullOwnAttemptOperation operation,
  ) async {
    final result = await recordAttempt?.completeOwnOperation(
      operation: operation,
      counted: true,
    );
    if (result case Ok(:final value?)) alertPort?.publish(value);
    if (result case Err()) {
      log.warning('recoverbull.attempts.monitoring.update.failed');
    }
  }
}
