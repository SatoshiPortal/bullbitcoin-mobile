import '../entities/attempt_monitoring_snapshot.dart';
import 'dart:async';

import '../repositories/recoverbull_repository.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_tor_route.dart';
import './ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';
import 'record_local_attempt_usecase.dart';
import '../entities/key_server_attempts.dart';
import '../recoverbull_attempt_alert_port.dart';

class FetchVaultKeyFromServerUsecase {
  final LogSink log;
  final RecoverBullRepository _recoverBullRepository;
  final EnsureRecoverBullTorSessionUsecase _ensureTorSessionUsecase;
  final RecordLocalAttemptUsecase? _recordAttempt;
  final RecoverBullAttemptAlertPort? _alertPort;

  FetchVaultKeyFromServerUsecase({
    required RecoverBullRepository repository,
    required EnsureRecoverBullTorSessionUsecase ensureTor,
    this._recordAttempt,
    this._alertPort,
    required this.log,
  }) : _recoverBullRepository = repository,
       _ensureTorSessionUsecase = ensureTor;

  Future<Result<String, RecoverBullFailure>> execute({
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

  Future<Result<String, RecoverBullFailure>> _fetch(
    EncryptedVault vault,
    String password,
    RecoverBullTorRoute session, {
    required bool ownsRoute,
  }) async {
    final started = await _recordAttempt?.beginOwnOperation(
      backupIdHex: vault.id,
      password: password,
    );
    final operation =
        started is Ok<RecoverBullOwnAttemptOperation?, RecoverBullFailure>
        ? started.value
        : null;
    var delegatedCompletion = false;
    try {
      final result = await _recoverBullRepository.fetchVaultKeyWithStatus(
        vault.id,
        password,
        vault.salt,
        session,
      );
      delegatedCompletion = true;
      return switch (result) {
        Ok(:final value) => _recordAndReturn(vault, value, operation),
        Err(:final failure) => _recordFailure(vault, failure, operation),
      };
    } finally {
      if (!delegatedCompletion && operation != null) {
        await _recordAttempt?.endOwnOperation(operation);
      }
      // Closing forwards to a native session stop, which can throw. Letting it
      // escape a `finally` would break the `Result` contract and, worse, discard
      // a vault key this call already retrieved.
      try {
        if (ownsRoute) await session.close();
      } on Exception catch (e, _) {
        log.warning(
          'recoverbull.tor.session.close.failed error_type=${e.runtimeType}',
        );
      }
    }
  }

  Future<Result<String, RecoverBullFailure>> _recordFailure(
    EncryptedVault vault,
    RecoverBullFailure failure,
    RecoverBullOwnAttemptOperation? operation,
  ) async {
    if (failure is KeyServerInvalidCredentialsFailure && operation != null) {
      unawaited(_record(vault, null, operation, counted: true));
      return Err(failure);
    }
    try {
      if (failure is KeyServerRateLimitedFailure) {
        try {
          final alert = await _recordAttempt?.recordTargetedLockout(
            backupIdHex: vault.id,
            operation: operation,
          );
          if (alert case Ok(value: final value?)) _alertPort?.publish(value);
        } on Exception catch (error, _) {
          log.warning(
            'recoverbull.attempts.monitoring.update.failed '
            'error_type=${error.runtimeType}',
          );
        }
      }
    } finally {
      if (operation != null) await _recordAttempt?.endOwnOperation(operation);
    }
    return Err(failure);
  }

  Future<Result<String, RecoverBullFailure>> _recordAndReturn(
    EncryptedVault vault,
    VaultKeyFetchResult value,
    RecoverBullOwnAttemptOperation? operation,
  ) async {
    final recording = _record(
      vault,
      value.attemptStatus,
      operation,
      counted: true,
    );
    // Without an inline attempt status, recording polls `/attempts` over its
    // own route and never raises an alert, so the user does not wait for it.
    if (value.attemptStatus == null) {
      unawaited(recording);
    } else {
      await recording;
    }
    return Ok(value.vaultKey);
  }

  Future<void> _record(
    EncryptedVault vault,
    KeyServerAttemptStatus? attemptStatus,
    RecoverBullOwnAttemptOperation? operation, {
    required bool counted,
  }) async {
    if (operation == null) return;
    try {
      final alert = await _recordAttempt?.completeOwnOperation(
        operation: operation,
        counted: counted,
        status: attemptStatus,
      );
      if (alert case Ok(:final value?)) _alertPort?.publish(value);
    } on Exception catch (error, _) {
      log.warning(
        'recoverbull.attempts.monitoring.update.failed '
        'error_type=${error.runtimeType}',
      );
    }
  }
}
