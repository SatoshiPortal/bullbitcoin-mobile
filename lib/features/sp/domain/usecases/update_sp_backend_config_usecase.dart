import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/sp_session_guard.dart';
import 'package:bb_mobile/features/sp/domain/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/is_sp_scanning_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secret;

class UpdateSpBackendConfigUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final GetSpSecretUsecase _getSpSecretUsecase;
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;
  final IsSpScanningUsecase _isSpScanningUsecase;
  final SpSessionGuard _guard;

  UpdateSpBackendConfigUsecase({
    required this._getSpFeatureGateUsecase,
    required this._getSpSecretUsecase,
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._ensureSpSessionUsecase,
    required this._isSpScanningUsecase,
    required this._guard,
  });

  /// Reopens the existing account with the selected servers under the same
  /// guard as revoke. Returns true when the session was reconfigured.
  @useResult
  Future<Result<bool, SpFailure>> execute({
    required BitcoinNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) => _update(
    network,
    (previous) => SpBackendConfig.parse(
      network: network,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
      minScanAmountSat: previous.minScanAmountSat,
    ),
  );

  @useResult
  Future<Result<bool, SpFailure>> setMinScanAmount({
    required BitcoinNetwork network,
    required int minScanAmountSat,
  }) => _update(
    network,
    (previous) => SpBackendConfig.parse(
      network: previous.network,
      blindbitUrl: previous.blindbitUrl,
      electrumUrl: previous.electrumUrl,
      fetchConcurrencyFactor: previous.fetchConcurrencyFactor,
      matchConcurrencyFactor: previous.matchConcurrencyFactor,
      minScanAmountSat: minScanAmountSat,
    ),
  );

  Future<Result<bool, SpFailure>> _update(
    BitcoinNetwork network,
    Result<SpBackendConfig, SpFailure> Function(SpBackendConfig) change,
  ) => _guard.exclusive(() async {
    try {
      final SpBackendConfig previous;
      switch (await _configRepository.fetch()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final config?):
          previous = config;
        case Ok():
          return const Err(SpNotSetUp());
      }
      if (previous.network != network ||
          !await _getSpFeatureGateUsecase.execute(config: previous)) {
        return const Err(SpUnsupportedNetwork());
      }

      final SpBackendConfig config;
      switch (change(previous)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          config = value;
      }
      if (config == previous) return const Ok(false);
      if (_isSpScanningUsecase.execute()) return const Err(SpScanBusy());

      final Secret secret;
      switch (await _getSpSecretUsecase.execute(network)) {
        case Ok(:final value):
          secret = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (!await _getSpFeatureGateUsecase.execute(config: previous)) {
        return const Err(SpUnsupportedNetwork());
      }
      if (_isSpScanningUsecase.execute()) return const Err(SpScanBusy());

      _repository.beginTeardown();
      try {
        switch (await _files.hasRevokedSentinel()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            return const Err(SpNotSetUp());
          case Ok():
            break;
        }
        if (await _repository.dispose() case Err(:final failure)) {
          return Err(failure);
        }
        switch (await _files.adoptNewestBackup()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: true):
            switch (await _files.hasRevokedSentinel()) {
              case Err(:final failure):
                return Err(failure);
              case Ok(value: true):
                return const Err(SpNotSetUp());
              case Ok():
                break;
            }
          case Ok():
            break;
        }
        switch (await _files.accountDirExists()) {
          case Err(:final failure):
            return Err(failure);
          case Ok(value: false):
            return const Err(SpNotSetUp());
          case Ok():
            break;
        }
        if (!await _getSpFeatureGateUsecase.execute(config: previous)) {
          return const Err(SpUnsupportedNetwork());
        }

        // Persist the settings before opening their session. Rollback can
        // change the saved config only after closing any replacement session.
        final result = await _saveAndOpen(config, secret);
        if (result case Err(:final failure)) {
          await _restorePrevious(previous);
          return Err(failure);
        }
        if (!await _getSpFeatureGateUsecase.execute(config: config)) {
          return const Err(SpUnsupportedNetwork());
        }
        return const Ok(true);
      } finally {
        _repository.endTeardown();
      }
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP backend update failed'));
    }
  });

  Future<Result<void, SpFailure>> _saveAndOpen(
    SpBackendConfig config,
    Secret secret,
  ) async {
    try {
      if (await _configRepository.save(config) case Err(:final failure)) {
        return Err(failure);
      }
      return await _repository.createFromSecret(
        network: config.network,
        secret: secret,
        blindbitUrl: config.blindbitUrl,
        electrumUrl: config.electrumUrl,
        fetchConcurrencyFactor: config.fetchConcurrencyFactor,
        matchConcurrencyFactor: config.matchConcurrencyFactor,
        minScanAmountSat: config.minScanAmountSat,
      );
    } on Exception catch (_) {
      return const Err(SpUnexpected('SP backend update failed'));
    }
  }

  Future<void> _restorePrevious(SpBackendConfig previous) async {
    if (await _repository.dispose() case Err(:final failure)) {
      log.warning(
        'SP backend rollback could not close session: ${failure.logMessage}',
      );
      return;
    }
    // Read first so a failed write that left the previous config intact can
    // recover without requiring another write.
    final unchanged = switch (await _configRepository.fetch()) {
      Ok(:final value) => value == previous,
      Err() => false,
    };
    if (!unchanged) {
      if (await _configRepository.save(previous) case Err(:final failure)) {
        log.warning(
          'SP backend rollback could not restore config: ${failure.logMessage}',
        );
        return;
      }
    }
    if (await _ensureSpSessionUsecase.execute(allowDuringTeardown: true)
        case Err(:final failure)) {
      log.warning(
        'SP backend rollback could not reopen session: ${failure.logMessage}',
      );
    }
  }
}
