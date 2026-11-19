import 'package:bb_mobile/features/sp/domain/usecases/get_sp_feature_gate_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:secrets/secrets.dart' show Secret;

/// Establishes the live SP session, reconstructing it via `createFromSecret`
/// from the persisted backend config (the FFI create path never writes a
/// reloadable config file, so `SpAccount.load` cannot be used).
///
/// Returns null when the wallet is not set up: a `.revoked` sentinel is present
/// or no backend config is stored. Reconstruction reuses the on-disk sqlite
/// stores, so balance and history survive.
///
/// Registered as a singleton so the in-flight guard serializes establishment:
/// concurrent callers (the SP shell `load()` and the wallet-side refresh on cold
/// start) share one `createFromSecret` instead of racing two live sessions.
class EnsureSpSessionUsecase {
  final GetSpFeatureGateUsecase _getSpFeatureGateUsecase;
  final SpAccountRepository _repository;
  final SpAccountFilesPort _files;
  final SpBackendConfigRepository _configRepository;
  final GetSpSecretUsecase _getSpSecretUsecase;

  EnsureSpSessionUsecase({
    required this._getSpFeatureGateUsecase,
    required this._repository,
    required this._files,
    required this._configRepository,
    required this._getSpSecretUsecase,
  });

  Future<Result<SpWallet?, SpFailure>>? _inFlight;

  /// `Ok(null)` when the wallet is not set up (revoked, no config, or a
  /// teardown is running); `Err` when a read or the establishment failed.
  ///
  /// [allowDuringTeardown] is for the one caller that runs *inside* a teardown
  /// it owns: a failed recreate rolling back has to re-establish the previous
  /// session while its own bracket is still held.
  Future<Result<SpWallet?, SpFailure>> execute({
    bool allowDuringTeardown = false,
  }) async {
    if (!await _getSpFeatureGateUsecase.execute(allowUnconfigured: true)) {
      return const Err(SpUnsupportedNetwork());
    }
    final SpBackendConfig config;
    switch (await _configRepository.fetchOrNull()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final stored?):
        config = stored;
      case Ok():
        return const Ok(null);
    }
    if (!await _getSpFeatureGateUsecase.execute(config: config)) {
      return const Err(SpUnsupportedNetwork());
    }
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }
    if (_repository.hasSession) {
      switch (await _files.hasRevokedSentinel()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: true):
          if (await _repository.dispose() case Err(:final failure)) {
            return Err(failure);
          }
          return const Ok(null);
        case Ok():
          break;
      }
      return _snapshot(config);
    }
    // Share native establishment, but each caller revalidates its own captured
    // config after waiting. Another caller's admitted context is not ours.
    final pending = _inFlight ??=
        _establish(
          config: config,
          allowDuringTeardown: allowDuringTeardown,
        ).whenComplete(() {
          _inFlight = null;
        });
    final result = await pending;
    if (!await _getSpFeatureGateUsecase.execute(config: config)) {
      return const Err(SpUnsupportedNetwork());
    }
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Ok(null);
      case Ok():
        return _snapshot(config);
    }
  }

  Future<Result<SpWallet?, SpFailure>> _snapshot(SpBackendConfig config) async {
    switch (_repository.network()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value == config.network:
        break;
      case Ok():
        return const Err(SpUnsupportedNetwork());
    }
    final snapshot = _repository.snapshot();
    if (!await _getSpFeatureGateUsecase.execute(config: config)) {
      return const Err(SpUnsupportedNetwork());
    }
    return switch (snapshot) {
      Err(:final failure) => Err(failure),
      Ok(value: final wallet) => Ok(
        SpWallet(
          network: config.network,
          spAddress: wallet.spAddress,
          balance: wallet.balance,
          isScanning: wallet.isScanning,
          lastScannedHeight: wallet.lastScannedHeight,
        ),
      ),
    };
  }

  Future<Result<SpWallet?, SpFailure>> _establish({
    required SpBackendConfig config,
    required bool allowDuringTeardown,
  }) async {
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }
    // A recreate that crashed between the backup and the create left no account
    // dir and a backup beside it; put it back before anything reads the dir, so
    // the wallet is recovered instead of re-created empty.
    if (await _files.adoptNewestBackup() case Err(:final failure)) {
      return Err(failure);
    }
    // A `.revoked` sentinel means a prior revoke deleted (or tried to) this
    // wallet; never reload it.
    switch (await _files.hasRevokedSentinel()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: true):
        return const Ok(null);
      case Ok():
        break;
    }

    final Secret secret;
    try {
      switch (await _getSpSecretUsecase.execute(config.network)) {
        case Ok(:final value):
          secret = value;
        case Err(:final failure):
          return Err(failure);
      }
    } on Exception catch (_) {
      // Fixed text: this block reads the secret, so the caught exception never
      // reaches a log.
      return const Err(SpUnexpected('SP session establish failed'));
    }

    // Re-check right before creating: a revoke/recreate may have begun teardown
    // during the awaits above, and creating now would race a live session.
    if (!allowDuringTeardown && _repository.teardownInProgress) {
      return const Ok(null);
    }

    if (!await _getSpFeatureGateUsecase.execute(config: config)) {
      return const Err(SpUnsupportedNetwork());
    }
    final created = await _repository.createFromSecret(
      network: config.network,
      secret: secret,
      blindbitUrl: config.blindbitUrl,
      electrumUrl: config.electrumUrl,
      fetchConcurrencyFactor: config.fetchConcurrencyFactor,
      matchConcurrencyFactor: config.matchConcurrencyFactor,
    );
    if (created case Err(:final failure)) return Err(failure);
    return _snapshot(config);
  }
}
