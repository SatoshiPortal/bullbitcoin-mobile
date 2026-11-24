import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/ports/sp_account_files_port.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/sp_session_guard.dart';
import 'package:silent/src/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:silent/src/domain/usecases/is_sp_scanning_usecase.dart';

/// Reconfigures the native session without replacing the wallet on disk.
class UpdateSpBackendConfigUsecase {
  final GetSpFeatureGateUsecase _gate;
  final SpAccountRepository _account;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configs;
  final EnsureSpSessionUsecase _ensureSession;
  final IsSpScanningUsecase _isScanning;
  final SpSessionGuard _guard;

  UpdateSpBackendConfigUsecase({
    required this._gate,
    required this._account,
    required this._files,
    required this._configs,
    required this._ensureSession,
    required this._isScanning,
    required this._guard,
  });

  @useResult
  Future<Result<bool, SilentFailure>> execute({
    required BitcoinNetwork network,
    String? blindbitUrl,
    String? electrumUrl,
    int? fetchConcurrencyFactor,
    int? matchConcurrencyFactor,
    int? minScanAmountSat,
  }) => _guard.exclusive(() async {
    final previous = await _configs.fetchOrNull();
    return switch (previous) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Err(SilentNotSetUp()),
      Ok(value: final config?) => _update(
        previous: config,
        network: network,
        next: SpBackendConfig.parse(
          network: network,
          blindbitUrl: blindbitUrl ?? config.blindbitUrl,
          electrumUrl: electrumUrl ?? config.electrumUrl,
          fetchConcurrencyFactor:
              fetchConcurrencyFactor ?? config.fetchConcurrencyFactor,
          matchConcurrencyFactor:
              matchConcurrencyFactor ?? config.matchConcurrencyFactor,
          minScanAmountSat: minScanAmountSat ?? config.minScanAmountSat,
        ),
      ),
    };
  });

  Future<Result<bool, SilentFailure>> _update({
    required SpBackendConfig previous,
    required BitcoinNetwork network,
    required Result<SpBackendConfig, SilentFailure> next,
  }) async {
    switch (next) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final config):
        if (network != previous.network) {
          return const Err(SilentUnsupportedNetwork());
        }
        switch (await _gate.check(network: network, config: previous)) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: false):
            return const Err(SilentUnsupportedNetwork());
          case Ok():
            break;
        }
        if (config == previous) return const Ok(false);
        if (_isScanning.execute()) return const Err(SilentScanBusy());
        if (await _files.adoptNewestBackup() case Err(:final failure)) {
          return Err(failure);
        }
        switch (await _files.hasRevokedSentinel()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(SilentNotSetUp());
          case Ok():
            break;
        }
        switch (await _files.accountDirExists()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: false):
            return const Err(SilentNotSetUp());
          case Ok():
            break;
        }
        switch (await _gate.check(network: network, config: previous)) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: false):
            return const Err(SilentUnsupportedNetwork());
          case Ok():
            break;
        }
        if (_isScanning.execute()) return const Err(SilentScanBusy());
        _account.beginTeardown();
        try {
          if (await _account.dispose() case Err(:final failure)) {
            return Err(failure);
          }
          final result = await _saveAndReopen(config);
          if (result case Err()) await _restore(previous);
          return result;
        } finally {
          _account.endTeardown();
        }
    }
  }

  Future<Result<bool, SilentFailure>> _saveAndReopen(
    SpBackendConfig config,
  ) async {
    try {
      if (await _configs.save(config) case Err(:final failure)) {
        return Err(failure);
      }
      return switch (await _ensureSession.execute(allowDuringTeardown: true)) {
        Err(:final failure) => Err(failure),
        Ok(value: null) => const Err(SilentNotSetUp()),
        Ok() => const Ok(true),
      };
    } on Exception {
      return const Err(SilentUnexpected('SP backend update failed'));
    }
  }

  Future<void> _restore(SpBackendConfig previous) async {
    try {
      if (await _account.dispose() case Err()) {
        log.warning('SP backend rollback could not close the new session');
        return;
      }
      final unchanged = switch (await _configs.fetchOrNull()) {
        Ok(:final value) => value == previous,
        Err() => false,
      };
      if (!unchanged) {
        if (await _configs.save(previous) case Err()) {
          log.warning('SP backend rollback could not restore configuration');
          return;
        }
      }
      if (await _ensureSession.execute(allowDuringTeardown: true) case Err()) {
        log.warning('SP backend rollback could not reopen the old session');
      }
    } on Exception {
      log.warning('SP backend rollback failed');
    }
  }
}
